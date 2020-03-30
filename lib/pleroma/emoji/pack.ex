defmodule Pleroma.Emoji.Pack do
  @derive {Jason.Encoder, only: [:files, :pack]}
  defstruct files: %{},
            pack_file: nil,
            path: nil,
            pack: %{},
            name: nil

  @type t() :: %__MODULE__{
          files: %{String.t() => Path.t()},
          pack_file: Path.t(),
          path: Path.t(),
          pack: map(),
          name: String.t()
        }

  alias Pleroma.Emoji

  @spec emoji_path() :: Path.t()
  def emoji_path do
    static = Pleroma.Config.get!([:instance, :static_dir])
    Path.join(static, "emoji")
  end

  @spec create(String.t()) :: :ok | {:error, File.posix()} | {:error, :empty_values}
  def create(name) when byte_size(name) > 0 do
    dir = Path.join(emoji_path(), name)

    with :ok <- File.mkdir(dir) do
      %__MODULE__{
        pack_file: Path.join(dir, "pack.json")
      }
      |> save_pack()
    end
  end

  def create(_), do: {:error, :empty_values}

  @spec show(String.t()) :: {:ok, t()} | {:loaded, nil} | {:error, :empty_values}
  def show(name) when byte_size(name) > 0 do
    with {_, %__MODULE__{} = pack} <- {:loaded, load_pack(name)},
         {_, pack} <- validate_pack(pack) do
      {:ok, pack}
    end
  end

  def show(_), do: {:error, :empty_values}

  @spec delete(String.t()) ::
          {:ok, [binary()]} | {:error, File.posix(), binary()} | {:error, :empty_values}
  def delete(name) when byte_size(name) > 0 do
    emoji_path()
    |> Path.join(name)
    |> File.rm_rf()
  end

  def delete(_), do: {:error, :empty_values}

  @spec add_file(String.t(), String.t(), Path.t(), Plug.Upload.t() | String.t()) ::
          {:ok, t()} | {:error, File.posix()} | {:error, :empty_values}
  def add_file(name, shortcode, filename, file)
      when byte_size(name) > 0 and byte_size(shortcode) > 0 and byte_size(filename) > 0 do
    with {_, nil} <- {:exists, Emoji.get(shortcode)},
         {_, %__MODULE__{} = pack} <- {:loaded, load_pack(name)} do
      file_path = Path.join(pack.path, filename)

      create_subdirs(file_path)

      case file do
        %Plug.Upload{path: upload_path} ->
          # Copy the uploaded file from the temporary directory
          File.copy!(upload_path, file_path)

        url when is_binary(url) ->
          # Download and write the file
          file_contents = Tesla.get!(url).body
          File.write!(file_path, file_contents)
      end

      files = Map.put(pack.files, shortcode, filename)

      updated_pack = %{pack | files: files}

      case save_pack(updated_pack) do
        :ok ->
          Emoji.reload()
          {:ok, updated_pack}

        e ->
          e
      end
    end
  end

  def add_file(_, _, _, _), do: {:error, :empty_values}

  defp create_subdirs(file_path) do
    if String.contains?(file_path, "/") do
      file_path
      |> Path.dirname()
      |> File.mkdir_p!()
    end
  end

  @spec delete_file(String.t(), String.t()) ::
          {:ok, t()} | {:error, File.posix()} | {:error, :empty_values}
  def delete_file(name, shortcode) when byte_size(name) > 0 and byte_size(shortcode) > 0 do
    with {_, %__MODULE__{} = pack} <- {:loaded, load_pack(name)},
         {_, {filename, files}} when not is_nil(filename) <-
           {:exists, Map.pop(pack.files, shortcode)},
         emoji <- Path.join(pack.path, filename),
         {_, true} <- {:exists, File.exists?(emoji)} do
      emoji_dir = Path.dirname(emoji)

      File.rm!(emoji)

      if String.contains?(filename, "/") and File.ls!(emoji_dir) == [] do
        File.rmdir!(emoji_dir)
      end

      updated_pack = %{pack | files: files}

      case save_pack(updated_pack) do
        :ok ->
          Emoji.reload()
          {:ok, updated_pack}

        e ->
          e
      end
    end
  end

  def delete_file(_, _), do: {:error, :empty_values}

  @spec update_file(String.t(), String.t(), String.t(), String.t(), boolean()) ::
          {:ok, t()} | {:error, File.posix()} | {:error, :empty_values}
  def update_file(name, shortcode, new_shortcode, new_filename, force)
      when byte_size(name) > 0 and byte_size(shortcode) > 0 and byte_size(new_shortcode) > 0 and
             byte_size(new_filename) > 0 do
    with {_, %__MODULE__{} = pack} <- {:loaded, load_pack(name)},
         {_, {filename, files}} when not is_nil(filename) <-
           {:exists, Map.pop(pack.files, shortcode)},
         {_, true} <- {:not_used, force or is_nil(Emoji.get(new_shortcode))} do
      old_path = Path.join(pack.path, filename)
      old_dir = Path.dirname(old_path)
      new_path = Path.join(pack.path, new_filename)

      create_subdirs(new_path)

      :ok = File.rename(old_path, new_path)

      if String.contains?(filename, "/") and File.ls!(old_dir) == [] do
        File.rmdir!(old_dir)
      end

      files = Map.put(files, new_shortcode, new_filename)

      updated_pack = %{pack | files: files}

      case save_pack(updated_pack) do
        :ok ->
          Emoji.reload()
          {:ok, updated_pack}

        e ->
          e
      end
    end
  end

  def update_file(_, _, _, _, _), do: {:error, :empty_values}

  @spec import_from_filesystem() :: {:ok, [String.t()]} | {:error, atom()}
  def import_from_filesystem do
    emoji_path = emoji_path()

    with {:ok, %{access: :read_write}} <- File.stat(emoji_path),
         {:ok, results} <- File.ls(emoji_path) do
      names =
        results
        |> Enum.map(&Path.join(emoji_path, &1))
        |> Enum.reject(fn path ->
          File.dir?(path) and File.exists?(Path.join(path, "pack.json"))
        end)
        |> Enum.map(&write_pack_contents/1)
        |> Enum.filter(& &1)

      {:ok, names}
    else
      {:ok, %{access: _}} -> {:error, :no_read_write}
      e -> e
    end
  end

  defp write_pack_contents(path) do
    pack = %__MODULE__{
      files: files_from_path(path),
      path: path,
      pack_file: Path.join(path, "pack.json")
    }

    case save_pack(pack) do
      :ok -> Path.basename(path)
      _ -> nil
    end
  end

  defp files_from_path(path) do
    txt_path = Path.join(path, "emoji.txt")

    if File.exists?(txt_path) do
      # There's an emoji.txt file, it's likely from a pack installed by the pack manager.
      # Make a pack.json file from the contents of that emoji.txt file

      # FIXME: Copy-pasted from Pleroma.Emoji/load_from_file_stream/2

      # Create a map of shortcodes to filenames from emoji.txt
      File.read!(txt_path)
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn line ->
        case String.split(line, ~r/,\s*/) do
          # This matches both strings with and without tags
          # and we don't care about tags here
          [name, file | _] ->
            file_dir_name = Path.dirname(file)

            file =
              if String.ends_with?(path, file_dir_name) do
                Path.basename(file)
              else
                file
              end

            {name, file}

          _ ->
            nil
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.into(%{})
    else
      # If there's no emoji.txt, assume all files
      # that are of certain extensions from the config are emojis and import them all
      pack_extensions = Pleroma.Config.get!([:emoji, :pack_extensions])
      Emoji.Loader.make_shortcode_to_file_map(path, pack_extensions)
    end
  end

  @spec list_remote(String.t()) :: {:ok, map()}
  def list_remote(url) do
    uri =
      url
      |> String.trim()
      |> URI.parse()

    with {_, true} <- {:shareable, shareable_packs_available?(uri)} do
      packs =
        uri
        |> URI.merge("/api/pleroma/emoji/packs")
        |> to_string()
        |> Tesla.get!()
        |> Map.get(:body)
        |> Jason.decode!()

      {:ok, packs}
    end
  end

  @spec list_local() :: {:ok, map()}
  def list_local do
    emoji_path = emoji_path()

    # Create the directory first if it does not exist. This is probably the first request made
    # with the API so it should be sufficient
    with {:create_dir, :ok} <- {:create_dir, File.mkdir_p(emoji_path)},
         {:ls, {:ok, results}} <- {:ls, File.ls(emoji_path)} do
      packs =
        results
        |> Enum.map(&load_pack/1)
        |> Enum.filter(& &1)
        |> Enum.map(&validate_pack/1)
        |> Map.new()

      {:ok, packs}
    end
  end

  defp validate_pack(pack) do
    if downloadable?(pack) do
      archive = fetch_archive(pack)
      archive_sha = :crypto.hash(:sha256, archive) |> Base.encode16()

      info =
        pack.pack
        |> Map.put("can-download", true)
        |> Map.put("download-sha256", archive_sha)

      {pack.name, Map.put(pack, :pack, info)}
    else
      info = Map.put(pack.pack, "can-download", false)
      {pack.name, Map.put(pack, :pack, info)}
    end
  end

  defp downloadable?(pack) do
    # If the pack is set as shared, check if it can be downloaded
    # That means that when asked, the pack can be packed and sent to the remote
    # Otherwise, they'd have to download it from external-src
    pack.pack["share-files"] &&
      Enum.all?(pack.files, fn {_, file} ->
        File.exists?(Path.join(pack.path, file))
      end)
  end

  @spec get_archive(String.t()) :: {:ok, binary()}
  def get_archive(name) do
    with {_, %__MODULE__{} = pack} <- {:exists?, load_pack(name)},
         {_, true} <- {:can_download?, downloadable?(pack)} do
      {:ok, fetch_archive(pack)}
    end
  end

  defp fetch_archive(pack) do
    hash = :crypto.hash(:md5, File.read!(pack.pack_file))

    case Cachex.get!(:emoji_packs_cache, pack.name) do
      %{hash: ^hash, pack_data: archive} ->
        archive

      _ ->
        create_archive_and_cache(pack, hash)
    end
  end

  defp create_archive_and_cache(pack, hash) do
    files = ['pack.json' | Enum.map(pack.files, fn {_, file} -> to_charlist(file) end)]

    {:ok, {_, result}} =
      :zip.zip('#{pack.name}.zip', files, [:memory, cwd: to_charlist(pack.path)])

    ttl_per_file = Pleroma.Config.get!([:emoji, :shared_pack_cache_seconds_per_file])
    overall_ttl = :timer.seconds(ttl_per_file * Enum.count(files))

    Cachex.put!(
      :emoji_packs_cache,
      pack.name,
      # if pack.json MD5 changes, the cache is not valid anymore
      %{hash: hash, pack_data: result},
      # Add a minute to cache time for every file in the pack
      ttl: overall_ttl
    )

    result
  end

  @spec download(String.t(), String.t(), String.t()) :: :ok
  def download(name, url, as) do
    uri =
      url
      |> String.trim()
      |> URI.parse()

    with {_, true} <- {:shareable, shareable_packs_available?(uri)} do
      remote_pack =
        uri
        |> URI.merge("/api/pleroma/emoji/packs/#{name}")
        |> to_string()
        |> Tesla.get!()
        |> Map.get(:body)
        |> Jason.decode!()

      result =
        case remote_pack["pack"] do
          %{"share-files" => true, "can-download" => true, "download-sha256" => sha} ->
            {:ok,
             %{
               sha: sha,
               url: URI.merge(uri, "/api/pleroma/emoji/packs/#{name}/archive") |> to_string()
             }}

          %{"fallback-src" => src, "fallback-src-sha256" => sha} when is_binary(src) ->
            {:ok,
             %{
               sha: sha,
               url: src,
               fallback: true
             }}

          _ ->
            {:error,
             "The pack was not set as shared and there is no fallback src to download from"}
        end

      with {:ok, %{sha: sha, url: url} = pinfo} <- result,
           %{body: archive} <- Tesla.get!(url),
           {_, true} <- {:checksum, Base.decode16!(sha) == :crypto.hash(:sha256, archive)} do
        local_name = as || name

        path = Path.join(emoji_path(), local_name)

        pack = %__MODULE__{
          name: local_name,
          path: path,
          files: remote_pack["files"],
          pack_file: Path.join(path, "pack.json")
        }

        File.mkdir_p!(pack.path)

        files = Enum.map(remote_pack["files"], fn {_, path} -> to_charlist(path) end)
        # Fallback cannot contain a pack.json file
        files = if pinfo[:fallback], do: files, else: ['pack.json' | files]

        {:ok, _} = :zip.unzip(archive, cwd: to_charlist(pack.path), file_list: files)

        # Fallback can't contain a pack.json file, since that would cause the fallback-src-sha256
        # in it to depend on itself
        if pinfo[:fallback] do
          save_pack(pack)
        end

        :ok
      end
    end
  end

  defp save_pack(pack), do: File.write(pack.pack_file, Jason.encode!(pack, pretty: true))

  @spec save_metadata(map(), t()) :: {:ok, t()} | {:error, File.posix()}
  def save_metadata(metadata, %__MODULE__{} = pack) do
    pack = Map.put(pack, :pack, metadata)

    with :ok <- save_pack(pack) do
      {:ok, pack}
    end
  end

  @spec update_metadata(String.t(), map()) :: {:ok, t()} | {:error, File.posix()}
  def update_metadata(name, data) do
    pack = load_pack(name)

    fb_sha_changed? =
      not is_nil(data["fallback-src"]) and data["fallback-src"] != pack.pack["fallback-src"]

    with {_, true} <- {:update?, fb_sha_changed?},
         {:ok, %{body: zip}} <- Tesla.get(data["fallback-src"]),
         {:ok, f_list} <- :zip.unzip(zip, [:memory]),
         {_, true} <- {:has_all_files?, has_all_files?(pack.files, f_list)} do
      fallback_sha = :crypto.hash(:sha256, zip) |> Base.encode16()

      data
      |> Map.put("fallback-src-sha256", fallback_sha)
      |> save_metadata(pack)
    else
      {:update?, _} -> save_metadata(data, pack)
      e -> e
    end
  end

  # Check if all files from the pack.json are in the archive
  defp has_all_files?(files, f_list) do
    Enum.all?(files, fn {_, from_manifest} ->
      List.keyfind(f_list, to_charlist(from_manifest), 0)
    end)
  end

  @spec load_pack(String.t()) :: t() | nil
  def load_pack(name) do
    pack_file = Path.join([emoji_path(), name, "pack.json"])

    if File.exists?(pack_file) do
      pack_file
      |> File.read!()
      |> from_json()
      |> Map.put(:pack_file, pack_file)
      |> Map.put(:path, Path.dirname(pack_file))
      |> Map.put(:name, name)
    end
  end

  defp from_json(json) do
    map = Jason.decode!(json)

    struct(__MODULE__, %{files: map["files"], pack: map["pack"]})
  end

  defp shareable_packs_available?(uri) do
    uri
    |> URI.merge("/.well-known/nodeinfo")
    |> to_string()
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
end
