defmodule Pleroma.Web.EmojiAPI.EmojiAPIController do
  use Pleroma.Web, :controller

  require Logger

  def reload(conn, _params) do
    Pleroma.Emoji.reload()

    conn |> text("ok")
  end

  @emoji_dir_path Path.join(
                    Pleroma.Config.get!([:instance, :static_dir]),
                    "emoji"
                  )

  @cache_seconds_per_file Pleroma.Config.get!([:emoji, :shared_pack_cache_seconds_per_file])

  @doc """
  Lists the packs available on the instance as JSON.

  The information is public and does not require authentification. The format is
  a map of "pack directory name" to pack.json contents.
  """
  def list_packs(conn, _params) do
    pack_infos =
      case File.ls(@emoji_dir_path) do
        {:error, _} ->
          %{}

        {:ok, results} ->
          results
          |> Enum.filter(fn file ->
            dir_path = Path.join(@emoji_dir_path, file)
            # Filter to only use the pack.json packs
            File.dir?(dir_path) and File.exists?(Path.join(dir_path, "pack.json"))
          end)
          |> Enum.map(fn pack_name ->
            pack_path = Path.join(@emoji_dir_path, pack_name)
            pack_file = Path.join(pack_path, "pack.json")

            {pack_name, Jason.decode!(File.read!(pack_file))}
          end)
          # Transform into a map of pack-name => pack-data
          # Check if all the files are in place and can be sent
          |> Enum.map(fn {name, pack} ->
            pack_path = Path.join(@emoji_dir_path, name)

            if can_download?(pack, pack_path) do
              archive_for_sha = make_archive(name, pack, pack_path)
              archive_sha = :crypto.hash(:sha256, archive_for_sha) |> Base.encode16()

              {name,
               pack
               |> put_in(["pack", "can-download"], true)
               |> put_in(["pack", "download-sha256"], archive_sha)}
            else
              {name,
               pack
               |> put_in(["pack", "can-download"], false)}
            end
          end)
          |> Enum.into(%{})
      end

    conn |> json(pack_infos)
  end

  defp can_download?(pack, pack_path) do
    # If the pack is set as shared, check if it can be downloaded
    # That means that when asked, the pack can be packed and sent to the remote
    # Otherwise, they'd have to download it from external-src
    pack["pack"]["share-files"] &&
      Enum.all?(pack["files"], fn {_, path} ->
        File.exists?(Path.join(pack_path, path))
      end)
  end

  defp create_archive_and_cache(name, pack, pack_dir, md5) do
    files =
      ['pack.json'] ++
        (pack["files"] |> Enum.map(fn {_, path} -> to_charlist(path) end))

    {:ok, {_, zip_result}} = :zip.zip('#{name}.zip', files, [:memory, cwd: to_charlist(pack_dir)])

    cache_ms = :timer.seconds(@cache_seconds_per_file * Enum.count(files))

    Cachex.put!(
      :emoji_packs_cache,
      name,
      # if pack.json MD5 changes, the cache is not valid anymore
      %{pack_json_md5: md5, pack_data: zip_result},
      # Add a minute to cache time for every file in the pack
      ttl: cache_ms
    )

    Logger.debug("Created an archive for the '#{name}' emoji pack, \
keeping it in cache for #{div(cache_ms, 1000)}s")

    zip_result
  end

  defp make_archive(name, pack, pack_dir) do
    # Having a different pack.json md5 invalidates cache
    pack_file_md5 = :crypto.hash(:md5, File.read!(Path.join(pack_dir, "pack.json")))

    case Cachex.get!(:emoji_packs_cache, name) do
      %{pack_file_md5: ^pack_file_md5, pack_data: zip_result} ->
        Logger.debug("Using cache for the '#{name}' shared emoji pack")
        zip_result

      _ ->
        create_archive_and_cache(name, pack, pack_dir, pack_file_md5)
    end
  end

  @doc """
  An endpoint for other instances (via admin UI) or users (via browser)
  to download packs that the instance shares.
  """
  def download_shared(conn, %{"name" => name}) do
    pack_dir = Path.join(@emoji_dir_path, name)
    pack_file = Path.join(pack_dir, "pack.json")

    if File.exists?(pack_file) do
      pack = Jason.decode!(File.read!(pack_file))

      if can_download?(pack, pack_dir) do
        zip_result = make_archive(name, pack, pack_dir)

        conn
        |> send_download({:binary, zip_result}, filename: "#{name}.zip")
      else
        {:error,
         conn
         |> put_status(:forbidden)
         |> text("Pack #{name} cannot be downloaded from this instance, either pack sharing\
           was disabled for this pack or some files are missing")}
      end
    else
      {:error,
       conn
       |> put_status(:not_found)
       |> text("Pack #{name} does not exist")}
    end
  end

  @doc """
  An admin endpoint to request downloading a pack named `pack_name` from the instance
  `instance_address`.

  If the requested instance's admin chose to share the pack, it will be downloaded
  from that instance, otherwise it will be downloaded from the fallback source, if there is one.
  """
  def download_from(conn, %{"instance_address" => address, "pack_name" => name} = data) do
    list_uri = "#{address}/api/pleroma/emoji/packs/list"

    list = Tesla.get!(list_uri).body |> Jason.decode!()
    full_pack = list[name]
    pfiles = full_pack["files"]
    pack = full_pack["pack"]

    pack_info_res =
      cond do
        pack["share-files"] && pack["can-download"] ->
          {:ok,
           %{
             sha: pack["download-sha256"],
             uri: "#{address}/api/pleroma/emoji/packs/download_shared/#{name}"
           }}

        pack["fallback-src"] ->
          {:ok,
           %{
             sha: pack["fallback-src-sha256"],
             uri: pack["fallback-src"],
             fallback: true
           }}

        true ->
          {:error, "The pack was not set as shared and there is no fallback src to download from"}
      end

    case pack_info_res do
      {:ok, %{sha: sha, uri: uri} = pinfo} ->
        sha = Base.decode16!(sha)
        emoji_archive = Tesla.get!(uri).body

        got_sha = :crypto.hash(:sha256, emoji_archive)

        if got_sha == sha do
          local_name = data["as"] || name
          pack_dir = Path.join(@emoji_dir_path, local_name)
          File.mkdir_p!(pack_dir)

          # Fallback cannot contain a pack.json file
          files =
            unless(pinfo[:fallback], do: ['pack.json'], else: []) ++
              (pfiles |> Enum.map(fn {_, path} -> to_charlist(path) end))

          {:ok, _} = :zip.unzip(emoji_archive, cwd: to_charlist(pack_dir), file_list: files)

          # Fallback can't contain a pack.json file, since that would cause the fallback-src-sha256
          # in it to depend on itself
          if pinfo[:fallback] do
            pack_file_path = Path.join(pack_dir, "pack.json")

            File.write!(pack_file_path, Jason.encode!(full_pack, pretty: true))
          end

          conn |> text("ok")
        else
          conn
          |> put_status(:internal_server_error)
          |> text("SHA256 for the pack doesn't match the one sent by the server")
        end

      {:error, e} ->
        conn |> put_status(:internal_server_error) |> text(e)
    end
  end

  @doc """
  Creates an empty pack named `name` which then can be updated via the admin UI.
  """
  def create(conn, %{"name" => name}) do
    pack_dir = Path.join(@emoji_dir_path, name)

    unless File.exists?(pack_dir) do
      File.mkdir_p!(pack_dir)

      pack_file_p = Path.join(pack_dir, "pack.json")

      File.write!(
        pack_file_p,
        Jason.encode!(%{pack: %{}, files: %{}})
      )

      conn |> text("ok")
    else
      conn
      |> put_status(:conflict)
      |> text("A pack named \"#{name}\" already exists")
    end
  end

  @doc """
  Deletes the pack `name` and all it's files.
  """
  def delete(conn, %{"name" => name}) do
    pack_dir = Path.join(@emoji_dir_path, name)

    case File.rm_rf(pack_dir) do
      {:ok, _} ->
        conn |> text("ok")

      {:error, _} ->
        conn |> put_status(:internal_server_error) |> text("Couldn't delete the pack #{name}")
    end
  end

  @doc """
  An endpoint to update `pack_names`'s metadata.

  `new_data` is the new metadata for the pack, that will replace the old metadata.
  """
  def update_metadata(conn, %{"pack_name" => name, "new_data" => new_data}) do
    pack_dir = Path.join(@emoji_dir_path, name)
    pack_file_p = Path.join(pack_dir, "pack.json")

    full_pack = Jason.decode!(File.read!(pack_file_p))

    # The new fallback-src is in the new data and it's not the same as it was in the old data
    should_update_fb_sha =
      not is_nil(new_data["fallback-src"]) and
        new_data["fallback-src"] != full_pack["pack"]["fallback-src"]

    new_data =
      if should_update_fb_sha do
        pack_arch = Tesla.get!(new_data["fallback-src"]).body

        {:ok, flist} = :zip.unzip(pack_arch, [:memory])

        # Check if all files from the pack.json are in the archive
        has_all_files =
          Enum.all?(full_pack["files"], fn {_, from_manifest} ->
            Enum.find(flist, fn {from_archive, _} ->
              to_string(from_archive) == from_manifest
            end)
          end)

        unless has_all_files do
          {:error,
           conn
           |> put_status(:bad_request)
           |> text("The fallback archive does not have all files specified in pack.json")}
        else
          fallback_sha = :crypto.hash(:sha256, pack_arch) |> Base.encode16()

          {:ok, new_data |> Map.put("fallback-src-sha256", fallback_sha)}
        end
      else
        {:ok, new_data}
      end

    case new_data do
      {:ok, new_data} ->
        full_pack = Map.put(full_pack, "pack", new_data)
        File.write!(pack_file_p, Jason.encode!(full_pack, pretty: true))

        # Send new data back with fallback sha filled
        conn |> json(new_data)

      {:error, e} ->
        e
    end
  end

  @doc """
  Updates a file in a pack.

  Updating can mean three things:

  - `add` adds an emoji named `shortcode` to the pack `pack_name`,
    that means that the emoji file needs to be uploaded with the request
    (thus requiring it to be a multipart request) and be named `file`.
    There can also be an optional `filename` that will be the new emoji file name
    (if it's not there, the name will be taken from the uploaded file).
  - `update` changes emoji shortcode (from `shortcode` to `new_shortcode` or moves the file
    (from the current filename to `new_filename`)
  - `remove` removes the emoji named `shortcode` and it's associated file
  """
  def update_file(
        conn,
        %{"pack_name" => pack_name, "action" => action, "shortcode" => shortcode} = params
      ) do
    pack_dir = Path.join(@emoji_dir_path, pack_name)
    pack_file_p = Path.join(pack_dir, "pack.json")

    full_pack = Jason.decode!(File.read!(pack_file_p))

    res =
      case action do
        "add" ->
          unless Map.has_key?(full_pack["files"], shortcode) do
            filename =
              if Map.has_key?(params, "filename") do
                params["filename"]
              else
                case params["file"] do
                  %Plug.Upload{filename: filename} -> filename
                  url when is_binary(url) -> Path.basename(url)
                end
              end

            unless String.trim(shortcode) |> String.length() == 0 or
                     String.trim(filename) |> String.length() == 0 do
              file_path = Path.join(pack_dir, filename)

              # If the name contains directories, create them
              if String.contains?(file_path, "/") do
                File.mkdir_p!(Path.dirname(file_path))
              end

              case params["file"] do
                %Plug.Upload{path: upload_path} ->
                  # Copy the uploaded file from the temporary directory
                  File.copy!(upload_path, file_path)

                url when is_binary(url) ->
                  # Download and write the file
                  file_contents = Tesla.get!(url).body
                  File.write!(file_path, file_contents)
              end

              updated_full_pack = put_in(full_pack, ["files", shortcode], filename)

              {:ok, updated_full_pack}
            else
              {:error,
               conn
               |> put_status(:bad_request)
               |> text("shortcode or filename cannot be empty")}
            end
          else
            {:error,
             conn
             |> put_status(:conflict)
             |> text("An emoji with the \"#{shortcode}\" shortcode already exists")}
          end

        "remove" ->
          if Map.has_key?(full_pack["files"], shortcode) do
            {emoji_file_path, updated_full_pack} = pop_in(full_pack, ["files", shortcode])

            emoji_file_path = Path.join(pack_dir, emoji_file_path)

            # Delete the emoji file
            File.rm!(emoji_file_path)

            # If the old directory has no more files, remove it
            if String.contains?(emoji_file_path, "/") do
              dir = Path.dirname(emoji_file_path)

              if Enum.empty?(File.ls!(dir)) do
                File.rmdir!(dir)
              end
            end

            {:ok, updated_full_pack}
          else
            {:error,
             conn |> put_status(:bad_request) |> text("Emoji \"#{shortcode}\" does not exist")}
          end

        "update" ->
          if Map.has_key?(full_pack["files"], shortcode) do
            with %{"new_shortcode" => new_shortcode, "new_filename" => new_filename} <- params do
              unless String.trim(new_shortcode) |> String.length() == 0 or
                       String.trim(new_filename) |> String.length() == 0 do
                # First, remove the old shortcode, saving the old path
                {old_emoji_file_path, updated_full_pack} = pop_in(full_pack, ["files", shortcode])
                old_emoji_file_path = Path.join(pack_dir, old_emoji_file_path)
                new_emoji_file_path = Path.join(pack_dir, new_filename)

                # If the name contains directories, create them
                if String.contains?(new_emoji_file_path, "/") do
                  File.mkdir_p!(Path.dirname(new_emoji_file_path))
                end

                # Move/Rename the old filename to a new filename
                # These are probably on the same filesystem, so just rename should work
                :ok = File.rename(old_emoji_file_path, new_emoji_file_path)

                # If the old directory has no more files, remove it
                if String.contains?(old_emoji_file_path, "/") do
                  dir = Path.dirname(old_emoji_file_path)

                  if Enum.empty?(File.ls!(dir)) do
                    File.rmdir!(dir)
                  end
                end

                # Then, put in the new shortcode with the new path
                updated_full_pack =
                  put_in(updated_full_pack, ["files", new_shortcode], new_filename)

                {:ok, updated_full_pack}
              else
                {:error,
                 conn
                 |> put_status(:bad_request)
                 |> text("new_shortcode or new_filename cannot be empty")}
              end
            else
              _ ->
                {:error,
                 conn
                 |> put_status(:bad_request)
                 |> text("new_shortcode or new_file were not specified")}
            end
          else
            {:error,
             conn |> put_status(:bad_request) |> text("Emoji \"#{shortcode}\" does not exist")}
          end

        _ ->
          {:error, conn |> put_status(:bad_request) |> text("Unknown action: #{action}")}
      end

    case res do
      {:ok, updated_full_pack} ->
        # Write the emoji pack file
        File.write!(pack_file_p, Jason.encode!(updated_full_pack, pretty: true))

        # Return the modified file list
        conn |> json(updated_full_pack["files"])

      {:error, e} ->
        e
    end
  end

  @doc """
  Imports emoji from the filesystem.

  Importing means checking all the directories in the
  `$instance_static/emoji/` for directories which do not have
  `pack.json`. If one has an emoji.txt file, that file will be used
  to create a `pack.json` file with it's contents. If the directory has
  neither, all the files with specific configured extenstions will be
  assumed to be emojis and stored in the new `pack.json` file.
  """
  def import_from_fs(conn, _params) do
    case File.ls(@emoji_dir_path) do
      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> text("Error accessing emoji pack directory")

      {:ok, results} ->
        imported_pack_names =
          results
          |> Enum.filter(fn file ->
            dir_path = Path.join(@emoji_dir_path, file)
            # Find the directories that do NOT have pack.json
            File.dir?(dir_path) and not File.exists?(Path.join(dir_path, "pack.json"))
          end)
          |> Enum.map(fn dir ->
            dir_path = Path.join(@emoji_dir_path, dir)
            emoji_txt_path = Path.join(dir_path, "emoji.txt")

            files_for_pack =
              if File.exists?(emoji_txt_path) do
                # There's an emoji.txt file, it's likely from a pack installed by the pack manager.
                # Make a pack.json file from the contents of that emoji.txt fileh

                # FIXME: Copy-pasted from Pleroma.Emoji/load_from_file_stream/2

                # Create a map of shortcodes to filenames from emoji.txt

                File.read!(emoji_txt_path)
                |> String.split("\n")
                |> Enum.map(&String.trim/1)
                |> Enum.map(fn line ->
                  case String.split(line, ~r/,\s*/) do
                    # This matches both strings with and without tags
                    # and we don't care about tags here
                    [name, file | _] ->
                      {name, file}

                    _ ->
                      nil
                  end
                end)
                |> Enum.filter(fn x -> not is_nil(x) end)
                |> Enum.into(%{})
              else
                # If there's no emoji.txt, assume all files
                # that are of certain extensions from the config are emojis and import them all
                Pleroma.Emoji.make_shortcode_to_file_map(
                  dir_path,
                  Pleroma.Config.get!([:emoji, :pack_extensions])
                )
              end

            pack_json_contents = Jason.encode!(%{pack: %{}, files: files_for_pack})

            File.write!(
              Path.join(dir_path, "pack.json"),
              pack_json_contents
            )

            dir
          end)

        conn |> json(imported_pack_names)
    end
  end
end
