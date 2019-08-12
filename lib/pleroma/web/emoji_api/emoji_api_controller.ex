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

  def list_packs(conn, _params) do
    pack_infos =
      case File.ls(@emoji_dir_path) do
        {:error, _} ->
          %{}

        {:ok, results} ->
          results
          |> Enum.filter(fn file ->
            dir_path = Path.join(@emoji_dir_path, file)
            # Filter to only use the pack.yml packs
            File.dir?(dir_path) and File.exists?(Path.join(dir_path, "pack.yml"))
          end)
          |> Enum.map(fn pack_name ->
            pack_path = Path.join(@emoji_dir_path, pack_name)
            pack_file = Path.join(pack_path, "pack.yml")

            {pack_name, RelaxYaml.Decoder.read_from_file(pack_file)}
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
    pack["pack"]["share-files"] and
      Enum.all?(pack["files"], fn {_, path} ->
        File.exists?(Path.join(pack_path, path))
      end)
  end

  defp create_archive_and_cache(name, pack, pack_dir, md5) do
    files =
      ['pack.yml'] ++
        (pack["files"] |> Enum.map(fn {_, path} -> to_charlist(path) end))

    {:ok, {_, zip_result}} = :zip.zip('#{name}.zip', files, [:memory, cwd: to_charlist(pack_dir)])

    cache_ms = :timer.seconds(@cache_seconds_per_file * Enum.count(files))

    Cachex.put!(
      :emoji_packs_cache,
      name,
      # if pack.yml MD5 changes, the cache is not valid anymore
      %{pack_yml_md5: md5, pack_data: zip_result},
      # Add a minute to cache time for every file in the pack
      ttl: cache_ms
    )

    Logger.debug("Create an archive for the '#{name}' shared emoji pack, \
keeping it in cache for #{div(cache_ms, 1000)}s")

    zip_result
  end

  defp make_archive(name, pack, pack_dir) do
    # Having a different pack.yml md5 invalidates cache
    pack_yml_md5 = :crypto.hash(:md5, File.read!(Path.join(pack_dir, "pack.yml")))

    maybe_cached_pack = Cachex.get!(:emoji_packs_cache, name)

    zip_result =
      if is_nil(maybe_cached_pack) do
        create_archive_and_cache(name, pack, pack_dir, pack_yml_md5)
      else
        if maybe_cached_pack[:pack_yml_md5] == pack_yml_md5 do
          Logger.debug("Using cache for the '#{name}' shared emoji pack")

          maybe_cached_pack[:pack_data]
        else
          create_archive_and_cache(name, pack, pack_dir, pack_yml_md5)
        end
      end

    zip_result
  end

  def download_shared(conn, %{"name" => name}) do
    pack_dir = Path.join(@emoji_dir_path, name)
    pack_yaml = Path.join(pack_dir, "pack.yml")

    if File.exists?(pack_yaml) do
      pack = RelaxYaml.Decoder.read_from_file(pack_yaml)

      if can_download?(pack, pack_dir) do
        zip_result = make_archive(name, pack, pack_dir)

        conn
        |> send_download({:binary, zip_result}, filename: "#{name}.zip")
      else
        {:error,
         conn
         |> put_status(:forbidden)
         |> json("Pack #{name} cannot be downloaded from this instance, either pack sharing\
           was disabled for this pack or some files are missing")}
      end
    else
      {:error,
       conn
       |> put_status(:not_found)
       |> json("Pack #{name} does not exist")}
    end
  end

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
          {:error, "The pack was not set as shared and the is no fallback url to download from"}
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

          files =
            ['pack.yml'] ++
              (pfiles |> Enum.map(fn {_, path} -> to_charlist(path) end))

          {:ok, _} = :zip.unzip(emoji_archive, cwd: to_charlist(pack_dir), file_list: files)

          # Fallback URL might not contain a pack.yml file. Put on we have if there's none
          if pinfo[:fallback] do
            yaml_path = Path.join(pack_dir, "pack.yml")

            unless File.exists?(yaml_path) do
              File.write!(yaml_path, RelaxYaml.Encoder.encode(full_pack, []))
            end
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
end
