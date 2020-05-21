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

  @spec create(String.t()) :: :ok | {:error, File.posix()} | {:error, :empty_values}
  def create(name) do
    with :ok <- validate_not_empty([name]),
         dir <- Path.join(emoji_path(), name),
         :ok <- File.mkdir(dir) do
      %__MODULE__{pack_file: Path.join(dir, "pack.json")}
      |> save_pack()
    end
  end

  @spec show(String.t()) :: {:ok, t()} | {:error, atom()}
  def show(name) do
    with :ok <- validate_not_empty([name]),
         {:ok, pack} <- load_pack(name) do
      {:ok, validate_pack(pack)}
    end
  end

  @spec delete(String.t()) ::
          {:ok, [binary()]} | {:error, File.posix(), binary()} | {:error, :empty_values}
  def delete(name) do
    with :ok <- validate_not_empty([name]) do
      emoji_path()
      |> Path.join(name)
      |> File.rm_rf()
    end
  end

  @spec add_file(String.t(), String.t(), Path.t(), Plug.Upload.t() | String.t()) ::
          {:ok, t()} | {:error, File.posix() | atom()}
  def add_file(name, shortcode, filename, file) do
    with :ok <- validate_not_empty([name, shortcode, filename]),
         :ok <- validate_emoji_not_exists(shortcode),
         {:ok, pack} <- load_pack(name),
         :ok <- save_file(file, pack, filename),
         {:ok, updated_pack} <- pack |> put_emoji(shortcode, filename) |> save_pack() do
      Emoji.reload()
      {:ok, updated_pack}
    end
  end

  @spec delete_file(String.t(), String.t()) ::
          {:ok, t()} | {:error, File.posix() | atom()}
  def delete_file(name, shortcode) do
    with :ok <- validate_not_empty([name, shortcode]),
         {:ok, pack} <- load_pack(name),
         :ok <- remove_file(pack, shortcode),
         {:ok, updated_pack} <- pack |> delete_emoji(shortcode) |> save_pack() do
      Emoji.reload()
      {:ok, updated_pack}
    end
  end

  @spec update_file(String.t(), String.t(), String.t(), String.t(), boolean()) ::
          {:ok, t()} | {:error, File.posix() | atom()}
  def update_file(name, shortcode, new_shortcode, new_filename, force) do
    with :ok <- validate_not_empty([name, shortcode, new_shortcode, new_filename]),
         {:ok, pack} <- load_pack(name),
         {:ok, filename} <- get_filename(pack, shortcode),
         :ok <- validate_emoji_not_exists(new_shortcode, force),
         :ok <- rename_file(pack, filename, new_filename),
         {:ok, updated_pack} <-
           pack
           |> delete_emoji(shortcode)
           |> put_emoji(new_shortcode, new_filename)
           |> save_pack() do
      Emoji.reload()
      {:ok, updated_pack}
    end
  end

  @spec import_from_filesystem() :: {:ok, [String.t()]} | {:error, File.posix() | atom()}
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
        |> Enum.reject(&is_nil/1)

      {:ok, names}
    else
      {:ok, %{access: _}} -> {:error, :no_read_write}
      e -> e
    end
  end

  @spec list_remote(String.t()) :: {:ok, map()} | {:error, atom()}
  def list_remote(url) do
    uri = url |> String.trim() |> URI.parse()

    with :ok <- validate_shareable_packs_available(uri) do
      uri
      |> URI.merge("/api/pleroma/emoji/packs")
      |> http_get()
    end
  end

  @spec list_local() :: {:ok, map()}
  def list_local do
    with {:ok, results} <- list_packs_dir() do
      packs =
        results
        |> Enum.map(fn name ->
          case load_pack(name) do
            {:ok, pack} -> pack
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new(fn pack -> {pack.name, validate_pack(pack)} end)

      {:ok, packs}
    end
  end

  @spec get_archive(String.t()) :: {:ok, binary()} | {:error, atom()}
  def get_archive(name) do
    with {:ok, pack} <- load_pack(name),
         :ok <- validate_downloadable(pack) do
      {:ok, fetch_archive(pack)}
    end
  end

  @spec download(String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  def download(name, url, as) do
    uri = url |> String.trim() |> URI.parse()

    with :ok <- validate_shareable_packs_available(uri),
         {:ok, remote_pack} <- uri |> URI.merge("/api/pleroma/emoji/packs/#{name}") |> http_get(),
         {:ok, %{sha: sha, url: url} = pack_info} <- fetch_pack_info(remote_pack, uri, name),
         {:ok, archive} <- download_archive(url, sha),
         pack <- copy_as(remote_pack, as || name),
         {:ok, _} = unzip(archive, pack_info, remote_pack, pack) do
      # Fallback can't contain a pack.json file, since that would cause the fallback-src-sha256
      # in it to depend on itself
      if pack_info[:fallback] do
        save_pack(pack)
      else
        {:ok, pack}
      end
    end
  end

  @spec save_metadata(map(), t()) :: {:ok, t()} | {:error, File.posix()}
  def save_metadata(metadata, %__MODULE__{} = pack) do
    pack
    |> Map.put(:pack, metadata)
    |> save_pack()
  end

  @spec update_metadata(String.t(), map()) :: {:ok, t()} | {:error, File.posix()}
  def update_metadata(name, data) do
    with {:ok, pack} <- load_pack(name) do
      if fallback_sha_changed?(pack, data) do
        update_sha_and_save_metadata(pack, data)
      else
        save_metadata(data, pack)
      end
    end
  end

  @spec load_pack(String.t()) :: {:ok, t()} | {:error, :not_found}
  def load_pack(name) do
    pack_file = Path.join([emoji_path(), name, "pack.json"])

    if File.exists?(pack_file) do
      pack =
        pack_file
        |> File.read!()
        |> from_json()
        |> Map.put(:pack_file, pack_file)
        |> Map.put(:path, Path.dirname(pack_file))
        |> Map.put(:name, name)

      {:ok, pack}
    else
      {:error, :not_found}
    end
  end

  @spec emoji_path() :: Path.t()
  defp emoji_path do
    [:instance, :static_dir]
    |> Pleroma.Config.get!()
    |> Path.join("emoji")
  end

  defp validate_emoji_not_exists(shortcode, force \\ false)
  defp validate_emoji_not_exists(_shortcode, true), do: :ok

  defp validate_emoji_not_exists(shortcode, _) do
    case Emoji.get(shortcode) do
      nil -> :ok
      _ -> {:error, :already_exists}
    end
  end

  defp write_pack_contents(path) do
    pack = %__MODULE__{
      files: files_from_path(path),
      path: path,
      pack_file: Path.join(path, "pack.json")
    }

    case save_pack(pack) do
      {:ok, _pack} -> Path.basename(path)
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
      txt_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn line ->
        case String.split(line, ~r/,\s*/) do
          # This matches both strings with and without tags
          # and we don't care about tags here
          [name, file | _] ->
            file_dir_name = Path.dirname(file)

            if String.ends_with?(path, file_dir_name) do
              {name, Path.basename(file)}
            else
              {name, file}
            end

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()
    else
      # If there's no emoji.txt, assume all files
      # that are of certain extensions from the config are emojis and import them all
      pack_extensions = Pleroma.Config.get!([:emoji, :pack_extensions])
      Emoji.Loader.make_shortcode_to_file_map(path, pack_extensions)
    end
  end

  defp validate_pack(pack) do
    info =
      if downloadable?(pack) do
        archive = fetch_archive(pack)
        archive_sha = :crypto.hash(:sha256, archive) |> Base.encode16()

        pack.pack
        |> Map.put("can-download", true)
        |> Map.put("download-sha256", archive_sha)
      else
        Map.put(pack.pack, "can-download", false)
      end

    Map.put(pack, :pack, info)
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

  defp save_pack(pack) do
    with {:ok, json} <- Jason.encode(pack, pretty: true),
         :ok <- File.write(pack.pack_file, json) do
      {:ok, pack}
    end
  end

  defp from_json(json) do
    map = Jason.decode!(json)

    struct(__MODULE__, %{files: map["files"], pack: map["pack"]})
  end

  defp validate_shareable_packs_available(uri) do
    with {:ok, %{"links" => links}} <- uri |> URI.merge("/.well-known/nodeinfo") |> http_get(),
         # Get the actual nodeinfo address and fetch it
         {:ok, %{"metadata" => %{"features" => features}}} <-
           links |> List.last() |> Map.get("href") |> http_get() do
      if Enum.member?(features, "shareable_emoji_packs") do
        :ok
      else
        {:error, :not_shareable}
      end
    end
  end

  defp validate_not_empty(list) do
    if Enum.all?(list, fn i -> is_binary(i) and i != "" end) do
      :ok
    else
      {:error, :empty_values}
    end
  end

  defp save_file(file, pack, filename) do
    file_path = Path.join(pack.path, filename)
    create_subdirs(file_path)

    case file do
      %Plug.Upload{path: upload_path} ->
        # Copy the uploaded file from the temporary directory
        with {:ok, _} <- File.copy(upload_path, file_path), do: :ok

      url when is_binary(url) ->
        # Download and write the file
        file_contents = Tesla.get!(url).body
        File.write(file_path, file_contents)
    end
  end

  defp put_emoji(pack, shortcode, filename) do
    files = Map.put(pack.files, shortcode, filename)
    %{pack | files: files}
  end

  defp delete_emoji(pack, shortcode) do
    files = Map.delete(pack.files, shortcode)
    %{pack | files: files}
  end

  defp rename_file(pack, filename, new_filename) do
    old_path = Path.join(pack.path, filename)
    new_path = Path.join(pack.path, new_filename)
    create_subdirs(new_path)

    with :ok <- File.rename(old_path, new_path) do
      remove_dir_if_empty(old_path, filename)
    end
  end

  defp create_subdirs(file_path) do
    if String.contains?(file_path, "/") do
      file_path
      |> Path.dirname()
      |> File.mkdir_p!()
    end
  end

  defp remove_file(pack, shortcode) do
    with {:ok, filename} <- get_filename(pack, shortcode),
         emoji <- Path.join(pack.path, filename),
         :ok <- File.rm(emoji) do
      remove_dir_if_empty(emoji, filename)
    end
  end

  defp remove_dir_if_empty(emoji, filename) do
    dir = Path.dirname(emoji)

    if String.contains?(filename, "/") and File.ls!(dir) == [] do
      File.rmdir!(dir)
    else
      :ok
    end
  end

  defp get_filename(pack, shortcode) do
    with %{^shortcode => filename} when is_binary(filename) <- pack.files,
         true <- pack.path |> Path.join(filename) |> File.exists?() do
      {:ok, filename}
    else
      _ -> {:error, :doesnt_exist}
    end
  end

  defp http_get(%URI{} = url), do: url |> to_string() |> http_get()

  defp http_get(url) do
    with {:ok, %{body: body}} <- url |> Pleroma.HTTP.get() do
      Jason.decode(body)
    end
  end

  defp list_packs_dir do
    emoji_path = emoji_path()
    # Create the directory first if it does not exist. This is probably the first request made
    # with the API so it should be sufficient
    with {:create_dir, :ok} <- {:create_dir, File.mkdir_p(emoji_path)},
         {:ls, {:ok, results}} <- {:ls, File.ls(emoji_path)} do
      {:ok, results}
    else
      {:create_dir, {:error, e}} -> {:error, :create_dir, e}
      {:ls, {:error, e}} -> {:error, :ls, e}
    end
  end

  defp validate_downloadable(pack) do
    if downloadable?(pack), do: :ok, else: {:error, :cant_download}
  end

  defp copy_as(remote_pack, local_name) do
    path = Path.join(emoji_path(), local_name)

    %__MODULE__{
      name: local_name,
      path: path,
      files: remote_pack["files"],
      pack_file: Path.join(path, "pack.json")
    }
  end

  defp unzip(archive, pack_info, remote_pack, local_pack) do
    with :ok <- File.mkdir_p!(local_pack.path) do
      files = Enum.map(remote_pack["files"], fn {_, path} -> to_charlist(path) end)
      # Fallback cannot contain a pack.json file
      files = if pack_info[:fallback], do: files, else: ['pack.json' | files]

      :zip.unzip(archive, cwd: to_charlist(local_pack.path), file_list: files)
    end
  end

  defp fetch_pack_info(remote_pack, uri, name) do
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
        {:error, "The pack was not set as shared and there is no fallback src to download from"}
    end
  end

  defp download_archive(url, sha) do
    with {:ok, %{body: archive}} <- Tesla.get(url) do
      if Base.decode16!(sha) == :crypto.hash(:sha256, archive) do
        {:ok, archive}
      else
        {:error, :imvalid_checksum}
      end
    end
  end

  defp fetch_archive(pack) do
    hash = :crypto.hash(:md5, File.read!(pack.pack_file))

    case Cachex.get!(:emoji_packs_cache, pack.name) do
      %{hash: ^hash, pack_data: archive} -> archive
      _ -> create_archive_and_cache(pack, hash)
    end
  end

  defp fallback_sha_changed?(pack, data) do
    is_binary(data[:"fallback-src"]) and data[:"fallback-src"] != pack.pack["fallback-src"]
  end

  defp update_sha_and_save_metadata(pack, data) do
    with {:ok, %{body: zip}} <- Tesla.get(data[:"fallback-src"]),
         :ok <- validate_has_all_files(pack, zip) do
      fallback_sha = :sha256 |> :crypto.hash(zip) |> Base.encode16()

      data
      |> Map.put("fallback-src-sha256", fallback_sha)
      |> save_metadata(pack)
    end
  end

  defp validate_has_all_files(pack, zip) do
    with {:ok, f_list} <- :zip.unzip(zip, [:memory]) do
      # Check if all files from the pack.json are in the archive
      pack.files
      |> Enum.all?(fn {_, from_manifest} ->
        List.keyfind(f_list, to_charlist(from_manifest), 0)
      end)
      |> if(do: :ok, else: {:error, :incomplete})
    end
  end
end
