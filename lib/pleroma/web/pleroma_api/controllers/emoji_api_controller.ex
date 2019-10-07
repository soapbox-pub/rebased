defmodule Pleroma.Web.PleromaAPI.EmojiAPIController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug

  require Logger

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"]}
    when action in [
           :create,
           :delete,
           :download_from,
           :list_from,
           :import_from_fs,
           :update_file,
           :update_metadata
         ]
  )

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  def emoji_dir_path do
    Path.join(
      Pleroma.Config.get!([:instance, :static_dir]),
      "emoji"
    )
  end

  @doc """
  Lists packs from the remote instance.

  Since JS cannot ask remote instances for their packs due to CPS, it has to
  be done by the server
  """
  def list_from(conn, %{"instance_address" => address}) do
    address = String.trim(address)

    if shareable_packs_available(address) do
      list_resp =
        "#{address}/api/pleroma/emoji/packs" |> Tesla.get!() |> Map.get(:body) |> Jason.decode!()

      json(conn, list_resp)
    else
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  @doc """
  Lists the packs available on the instance as JSON.

  The information is public and does not require authentification. The format is
  a map of "pack directory name" to pack.json contents.
  """
  def list_packs(conn, _params) do
    # Create the directory first if it does not exist. This is probably the first request made
    # with the API so it should be sufficient
    with {:create_dir, :ok} <- {:create_dir, File.mkdir_p(emoji_dir_path())},
         {:ls, {:ok, results}} <- {:ls, File.ls(emoji_dir_path())} do
      pack_infos =
        results
        |> Enum.filter(&has_pack_json?/1)
        |> Enum.map(&load_pack/1)
        # Check if all the files are in place and can be sent
        |> Enum.map(&validate_pack/1)
        # Transform into a map of pack-name => pack-data
        |> Enum.into(%{})

      json(conn, pack_infos)
    else
      {:create_dir, {:error, e}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create the emoji pack directory at #{emoji_dir_path()}: #{e}"})

      {:ls, {:error, e}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error:
            "Failed to get the contents of the emoji pack directory at #{emoji_dir_path()}: #{e}"
        })
    end
  end

  defp has_pack_json?(file) do
    dir_path = Path.join(emoji_dir_path(), file)
    # Filter to only use the pack.json packs
    File.dir?(dir_path) and File.exists?(Path.join(dir_path, "pack.json"))
  end

  defp load_pack(pack_name) do
    pack_path = Path.join(emoji_dir_path(), pack_name)
    pack_file = Path.join(pack_path, "pack.json")

    {pack_name, Jason.decode!(File.read!(pack_file))}
  end

  defp validate_pack({name, pack}) do
    pack_path = Path.join(emoji_dir_path(), name)

    if can_download?(pack, pack_path) do
      archive_for_sha = make_archive(name, pack, pack_path)
      archive_sha = :crypto.hash(:sha256, archive_for_sha) |> Base.encode16()

      pack =
        pack
        |> put_in(["pack", "can-download"], true)
        |> put_in(["pack", "download-sha256"], archive_sha)

      {name, pack}
    else
      {name, put_in(pack, ["pack", "can-download"], false)}
    end
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

    cache_seconds_per_file = Pleroma.Config.get!([:emoji, :shared_pack_cache_seconds_per_file])
    cache_ms = :timer.seconds(cache_seconds_per_file * Enum.count(files))

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
    pack_dir = Path.join(emoji_dir_path(), name)
    pack_file = Path.join(pack_dir, "pack.json")

    with {_, true} <- {:exists?, File.exists?(pack_file)},
         pack = Jason.decode!(File.read!(pack_file)),
         {_, true} <- {:can_download?, can_download?(pack, pack_dir)} do
      zip_result = make_archive(name, pack, pack_dir)
      send_download(conn, {:binary, zip_result}, filename: "#{name}.zip")
    else
      {:can_download?, _} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Pack #{name} cannot be downloaded from this instance, either pack sharing\
           was disabled for this pack or some files are missing"
        })

      {:exists?, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})
    end
  end

  defp shareable_packs_available(address) do
    "#{address}/.well-known/nodeinfo"
    |> Tesla.get!()
    |> Map.get(:body)
    |> Jason.decode!()
    |> Map.get("links")
    |> List.last()
    |> Map.get("href")
    # Get the actual nodeinfo address and fetch it
    |> Tesla.get!()
    |> Map.get(:body)
    |> Jason.decode!()
    |> get_in(["metadata", "features"])
    |> Enum.member?("shareable_emoji_packs")
  end

  @doc """
  An admin endpoint to request downloading a pack named `pack_name` from the instance
  `instance_address`.

  If the requested instance's admin chose to share the pack, it will be downloaded
  from that instance, otherwise it will be downloaded from the fallback source, if there is one.
  """
  def download_from(conn, %{"instance_address" => address, "pack_name" => name} = data) do
    address = String.trim(address)

    if shareable_packs_available(address) do
      full_pack =
        "#{address}/api/pleroma/emoji/packs/list"
        |> Tesla.get!()
        |> Map.get(:body)
        |> Jason.decode!()
        |> Map.get(name)

      pack_info_res =
        case full_pack["pack"] do
          %{"share-files" => true, "can-download" => true, "download-sha256" => sha} ->
            {:ok,
             %{
               sha: sha,
               uri: "#{address}/api/pleroma/emoji/packs/download_shared/#{name}"
             }}

          %{"fallback-src" => src, "fallback-src-sha256" => sha} when is_binary(src) ->
            {:ok,
             %{
               sha: sha,
               uri: src,
               fallback: true
             }}

          _ ->
            {:error,
             "The pack was not set as shared and there is no fallback src to download from"}
        end

      with {:ok, %{sha: sha, uri: uri} = pinfo} <- pack_info_res,
           %{body: emoji_archive} <- Tesla.get!(uri),
           {_, true} <- {:checksum, Base.decode16!(sha) == :crypto.hash(:sha256, emoji_archive)} do
        local_name = data["as"] || name
        pack_dir = Path.join(emoji_dir_path(), local_name)
        File.mkdir_p!(pack_dir)

        files = Enum.map(full_pack["files"], fn {_, path} -> to_charlist(path) end)
        # Fallback cannot contain a pack.json file
        files = if pinfo[:fallback], do: files, else: ['pack.json'] ++ files

        {:ok, _} = :zip.unzip(emoji_archive, cwd: to_charlist(pack_dir), file_list: files)

        # Fallback can't contain a pack.json file, since that would cause the fallback-src-sha256
        # in it to depend on itself
        if pinfo[:fallback] do
          pack_file_path = Path.join(pack_dir, "pack.json")

          File.write!(pack_file_path, Jason.encode!(full_pack, pretty: true))
        end

        json(conn, "ok")
      else
        {:error, e} ->
          conn |> put_status(:internal_server_error) |> json(%{error: e})

        {:checksum, _} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "SHA256 for the pack doesn't match the one sent by the server"})
      end
    else
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  @doc """
  Creates an empty pack named `name` which then can be updated via the admin UI.
  """
  def create(conn, %{"name" => name}) do
    pack_dir = Path.join(emoji_dir_path(), name)

    if not File.exists?(pack_dir) do
      File.mkdir_p!(pack_dir)

      pack_file_p = Path.join(pack_dir, "pack.json")

      File.write!(
        pack_file_p,
        Jason.encode!(%{pack: %{}, files: %{}}, pretty: true)
      )

      conn |> json("ok")
    else
      conn
      |> put_status(:conflict)
      |> json(%{error: "A pack named \"#{name}\" already exists"})
    end
  end

  @doc """
  Deletes the pack `name` and all it's files.
  """
  def delete(conn, %{"name" => name}) do
    pack_dir = Path.join(emoji_dir_path(), name)

    case File.rm_rf(pack_dir) do
      {:ok, _} ->
        conn |> json("ok")

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Couldn't delete the pack #{name}"})
    end
  end

  @doc """
  An endpoint to update `pack_names`'s metadata.

  `new_data` is the new metadata for the pack, that will replace the old metadata.
  """
  def update_metadata(conn, %{"pack_name" => name, "new_data" => new_data}) do
    pack_file_p = Path.join([emoji_dir_path(), name, "pack.json"])

    full_pack = Jason.decode!(File.read!(pack_file_p))

    # The new fallback-src is in the new data and it's not the same as it was in the old data
    should_update_fb_sha =
      not is_nil(new_data["fallback-src"]) and
        new_data["fallback-src"] != full_pack["pack"]["fallback-src"]

    with {_, true} <- {:should_update?, should_update_fb_sha},
         %{body: pack_arch} <- Tesla.get!(new_data["fallback-src"]),
         {:ok, flist} <- :zip.unzip(pack_arch, [:memory]),
         {_, true} <- {:has_all_files?, has_all_files?(full_pack, flist)} do
      fallback_sha = :crypto.hash(:sha256, pack_arch) |> Base.encode16()

      new_data = Map.put(new_data, "fallback-src-sha256", fallback_sha)
      update_metadata_and_send(conn, full_pack, new_data, pack_file_p)
    else
      {:should_update?, _} ->
        update_metadata_and_send(conn, full_pack, new_data, pack_file_p)

      {:has_all_files?, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The fallback archive does not have all files specified in pack.json"})
    end
  end

  # Check if all files from the pack.json are in the archive
  defp has_all_files?(%{"files" => files}, flist) do
    Enum.all?(files, fn {_, from_manifest} ->
      Enum.find(flist, fn {from_archive, _} ->
        to_string(from_archive) == from_manifest
      end)
    end)
  end

  defp update_metadata_and_send(conn, full_pack, new_data, pack_file_p) do
    full_pack = Map.put(full_pack, "pack", new_data)
    File.write!(pack_file_p, Jason.encode!(full_pack, pretty: true))

    # Send new data back with fallback sha filled
    json(conn, new_data)
  end

  defp get_filename(%{"filename" => filename}), do: filename

  defp get_filename(%{"file" => file}) do
    case file do
      %Plug.Upload{filename: filename} -> filename
      url when is_binary(url) -> Path.basename(url)
    end
  end

  defp empty?(str), do: String.trim(str) == ""

  defp update_file_and_send(conn, updated_full_pack, pack_file_p) do
    # Write the emoji pack file
    File.write!(pack_file_p, Jason.encode!(updated_full_pack, pretty: true))

    # Return the modified file list
    json(conn, updated_full_pack["files"])
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

  # Add
  def update_file(
        conn,
        %{"pack_name" => pack_name, "action" => "add", "shortcode" => shortcode} = params
      ) do
    pack_dir = Path.join(emoji_dir_path(), pack_name)
    pack_file_p = Path.join(pack_dir, "pack.json")

    full_pack = Jason.decode!(File.read!(pack_file_p))

    with {_, false} <- {:has_shortcode, Map.has_key?(full_pack["files"], shortcode)},
         filename <- get_filename(params),
         false <- empty?(shortcode),
         false <- empty?(filename) do
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
      update_file_and_send(conn, updated_full_pack, pack_file_p)
    else
      {:has_shortcode, _} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      true ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "shortcode or filename cannot be empty"})
    end
  end

  # Remove
  def update_file(conn, %{
        "pack_name" => pack_name,
        "action" => "remove",
        "shortcode" => shortcode
      }) do
    pack_dir = Path.join(emoji_dir_path(), pack_name)
    pack_file_p = Path.join(pack_dir, "pack.json")

    full_pack = Jason.decode!(File.read!(pack_file_p))

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

      update_file_and_send(conn, updated_full_pack, pack_file_p)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})
    end
  end

  # Update
  def update_file(
        conn,
        %{"pack_name" => pack_name, "action" => "update", "shortcode" => shortcode} = params
      ) do
    pack_dir = Path.join(emoji_dir_path(), pack_name)
    pack_file_p = Path.join(pack_dir, "pack.json")

    full_pack = Jason.decode!(File.read!(pack_file_p))

    with {_, true} <- {:has_shortcode, Map.has_key?(full_pack["files"], shortcode)},
         %{"new_shortcode" => new_shortcode, "new_filename" => new_filename} <- params,
         false <- empty?(new_shortcode),
         false <- empty?(new_filename) do
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
      updated_full_pack = put_in(updated_full_pack, ["files", new_shortcode], new_filename)
      update_file_and_send(conn, updated_full_pack, pack_file_p)
    else
      {:has_shortcode, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      true ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "new_shortcode or new_filename cannot be empty"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "new_shortcode or new_file were not specified"})
    end
  end

  def update_file(conn, %{"action" => action}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Unknown action: #{action}"})
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
    with {:ok, results} <- File.ls(emoji_dir_path()) do
      imported_pack_names =
        results
        |> Enum.filter(fn file ->
          dir_path = Path.join(emoji_dir_path(), file)
          # Find the directories that do NOT have pack.json
          File.dir?(dir_path) and not File.exists?(Path.join(dir_path, "pack.json"))
        end)
        |> Enum.map(&write_pack_json_contents/1)

      json(conn, imported_pack_names)
    else
      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error accessing emoji pack directory"})
    end
  end

  defp write_pack_json_contents(dir) do
    dir_path = Path.join(emoji_dir_path(), dir)
    emoji_txt_path = Path.join(dir_path, "emoji.txt")

    files_for_pack = files_for_pack(emoji_txt_path, dir_path)
    pack_json_contents = Jason.encode!(%{pack: %{}, files: files_for_pack})

    File.write!(Path.join(dir_path, "pack.json"), pack_json_contents)

    dir
  end

  defp files_for_pack(emoji_txt_path, dir_path) do
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
          [name, file | _] -> {name, file}
          _ -> nil
        end
      end)
      |> Enum.filter(fn x -> not is_nil(x) end)
      |> Enum.into(%{})
    else
      # If there's no emoji.txt, assume all files
      # that are of certain extensions from the config are emojis and import them all
      pack_extensions = Pleroma.Config.get!([:emoji, :pack_extensions])
      Pleroma.Emoji.Loader.make_shortcode_to_file_map(dir_path, pack_extensions)
    end
  end
end
