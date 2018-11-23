defmodule Pleroma.Upload do
  alias Ecto.UUID
  require Logger

  @type upload_option ::
          {:dedupe, boolean()} | {:size_limit, non_neg_integer()} | {:uploader, module()}
  @type upload_source ::
          Plug.Upload.t() | data_uri_string() ::
          String.t() | {:from_local, name :: String.t(), uuid :: String.t(), path :: String.t()}

  @spec store(upload_source, options :: [upload_option()]) :: {:ok, Map.t()} | {:error, any()}
  def store(upload, opts \\ []) do
    opts = get_opts(opts)

    with {:ok, name, uuid, path, content_type} <- process_upload(upload, opts),
         _ <- strip_exif_data(content_type, path),
         {:ok, url_spec} <- opts.uploader.put_file(name, uuid, path, content_type, opts) do
      {:ok,
       %{
         "type" => "Image",
         "url" => [
           %{
             "type" => "Link",
             "mediaType" => content_type,
             "href" => url_from_spec(url_spec)
           }
         ],
         "name" => name
       }}
    else
      {:error, error} ->
        Logger.error(
          "#{__MODULE__} store (using #{inspect(opts.uploader)}) failed: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp get_opts(opts) do
    %{
      dedupe: Keyword.get(opts, :dedupe, Pleroma.Config.get([:instance, :dedupe_media])),
      size_limit: Keyword.get(opts, :size_limit, Pleroma.Config.get([:instance, :upload_limit])),
      uploader: Keyword.get(opts, :uploader, Pleroma.Config.get([__MODULE__, :uploader]))
    }
  end

  defp process_upload(%Plug.Upload{} = file, opts) do
    with :ok <- check_file_size(file.path, opts.size_limit),
         uuid <- get_uuid(file, opts.dedupe),
         content_type <- get_content_type(file.path),
         name <- get_name(file, uuid, content_type, opts.dedupe) do
      {:ok, name, uuid, file.path, content_type}
    end
  end

  defp process_upload(%{"img" => "data:image/" <> image_data}, opts) do
    parsed = Regex.named_captures(~r/(?<filetype>jpeg|png|gif);base64,(?<data>.*)/, image_data)
    data = Base.decode64!(parsed["data"], ignore: :whitespace)
    hash = String.downcase(Base.encode16(:crypto.hash(:sha256, data)))

    with :ok <- check_binary_size(data, opts.size_limit),
         tmp_path <- tempfile_for_image(data),
         content_type <- get_content_type(tmp_path),
         uuid <- UUID.generate(),
         name <- create_name(hash, parsed["filetype"], content_type) do
      {:ok, name, uuid, tmp_path, content_type}
    end
  end

  # For Mix.Tasks.MigrateLocalUploads
  defp process_upload({:from_local, name, uuid, path}, _opts) do
    with content_type <- get_content_type(path) do
      {:ok, name, uuid, path, content_type}
    end
  end

  defp check_binary_size(binary, size_limit)
       when is_integer(size_limit) and size_limit > 0 and byte_size(binary) >= size_limit do
    {:error, :file_too_large}
  end

  defp check_binary_size(_, _), do: :ok

  defp check_file_size(path, size_limit) when is_integer(size_limit) and size_limit > 0 do
    with {:ok, %{size: size}} <- File.stat(path),
         true <- size <= size_limit do
      :ok
    else
      false -> {:error, :file_too_large}
      error -> error
    end
  end

  defp check_file_size(_, _), do: :ok

  # Creates a tempfile using the Plug.Upload Genserver which cleans them up
  # automatically.
  defp tempfile_for_image(data) do
    {:ok, tmp_path} = Plug.Upload.random_file("profile_pics")
    {:ok, tmp_file} = File.open(tmp_path, [:write, :raw, :binary])
    IO.binwrite(tmp_file, data)

    tmp_path
  end

  defp strip_exif_data(content_type, file) do
    settings = Application.get_env(:pleroma, Pleroma.Upload)
    do_strip = Keyword.fetch!(settings, :strip_exif)
    [filetype, _ext] = String.split(content_type, "/")

    if filetype == "image" and do_strip == true do
      Mogrify.open(file) |> Mogrify.custom("strip") |> Mogrify.save(in_place: true)
    end
  end

  defp create_name(uuid, ext, type) do
    extension =
      cond do
        type == "application/octect-stream" -> ext
        ext = mime_extension(ext) -> ext
        true -> String.split(type, "/") |> List.last()
      end

    [uuid, extension]
    |> Enum.join(".")
    |> String.downcase()
  end

  defp mime_extension(type) do
    List.first(MIME.extensions(type))
  end

  defp get_uuid(file, should_dedupe) do
    if should_dedupe do
      Base.encode16(:crypto.hash(:sha256, File.read!(file.path)))
    else
      UUID.generate()
    end
  end

  defp get_name(file, uuid, type, should_dedupe) do
    if should_dedupe do
      create_name(uuid, List.last(String.split(file.filename, ".")), type)
    else
      parts = String.split(file.filename, ".")

      new_filename =
        if length(parts) > 1 do
          Enum.drop(parts, -1) |> Enum.join(".")
        else
          Enum.join(parts)
        end

      cond do
        type == "application/octet-stream" ->
          file.filename

        ext = mime_extension(type) ->
          new_filename <> "." <> ext

        true ->
          Enum.join([new_filename, String.split(type, "/") |> List.last()], ".")
      end
    end
  end

  def get_content_type(file) do
    match =
      File.open(file, [:read], fn f ->
        case IO.binread(f, 8) do
          <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> ->
            "image/png"

          <<0x47, 0x49, 0x46, 0x38, _, 0x61, _, _>> ->
            "image/gif"

          <<0xFF, 0xD8, 0xFF, _, _, _, _, _>> ->
            "image/jpeg"

          <<0x1A, 0x45, 0xDF, 0xA3, _, _, _, _>> ->
            "video/webm"

          <<0x00, 0x00, 0x00, _, 0x66, 0x74, 0x79, 0x70>> ->
            "video/mp4"

          <<0x49, 0x44, 0x33, _, _, _, _, _>> ->
            "audio/mpeg"

          <<255, 251, _, 68, 0, 0, 0, 0>> ->
            "audio/mpeg"

          <<0x4F, 0x67, 0x67, 0x53, 0x00, 0x02, 0x00, 0x00>> ->
            case IO.binread(f, 27) do
              <<_::size(160), 0x80, 0x74, 0x68, 0x65, 0x6F, 0x72, 0x61>> ->
                "video/ogg"

              _ ->
                "audio/ogg"
            end

          <<0x52, 0x49, 0x46, 0x46, _, _, _, _>> ->
            "audio/wav"

          _ ->
            "application/octet-stream"
        end
      end)

    case match do
      {:ok, type} -> type
      _e -> "application/octet-stream"
    end
  end

  defp uploader() do
    Pleroma.Config.get!([Pleroma.Upload, :uploader])
  end

  defp url_from_spec({:file, path}) do
    [Pleroma.Web.base_url(), "media", path]
    |> Path.join()
  end

  defp url_from_spec({:url, url}) do
    url
  end
end
