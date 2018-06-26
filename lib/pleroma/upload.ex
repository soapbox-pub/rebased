defmodule Pleroma.Upload do
  alias Ecto.UUID
  alias Pleroma.Web

  def store(%Plug.Upload{} = file, should_dedupe) do
    content_type = get_content_type(file.path)
    uuid = get_uuid(file, should_dedupe)
    name = get_name(file, uuid, content_type, should_dedupe)
    upload_folder = get_upload_path(uuid, should_dedupe)
    url_path = get_url(name, uuid, should_dedupe)

    File.mkdir_p!(upload_folder)
    result_file = Path.join(upload_folder, name)

    if File.exists?(result_file) do
      File.rm!(file.path)
    else
      File.cp!(file.path, result_file)
    end

    strip_exif_data(content_type, result_file)

    %{
      "type" => "Image",
      "url" => [
        %{
          "type" => "Link",
          "mediaType" => content_type,
          "href" => url_path
        }
      ],
      "name" => name
    }
  end

  def store(%{"img" => "data:image/" <> image_data}, should_dedupe) do
    parsed = Regex.named_captures(~r/(?<filetype>jpeg|png|gif);base64,(?<data>.*)/, image_data)
    data = Base.decode64!(parsed["data"], ignore: :whitespace)
    uuid = UUID.generate()
    uuidpath = Path.join(upload_path(), uuid)
    uuid = UUID.generate()

    File.mkdir_p!(upload_path())

    File.write!(uuidpath, data)

    content_type = get_content_type(uuidpath)

    name =
      create_name(
        String.downcase(Base.encode16(:crypto.hash(:sha256, data))),
        parsed["filetype"],
        content_type
      )

    upload_folder = get_upload_path(uuid, should_dedupe)
    url_path = get_url(name, uuid, should_dedupe)

    File.mkdir_p!(upload_folder)
    result_file = Path.join(upload_folder, name)

    if should_dedupe do
      if !File.exists?(result_file) do
        File.rename(uuidpath, result_file)
      else
        File.rm!(uuidpath)
      end
    else
      File.rename(uuidpath, result_file)
    end

    strip_exif_data(content_type, result_file)

    %{
      "type" => "Image",
      "url" => [
        %{
          "type" => "Link",
          "mediaType" => content_type,
          "href" => url_path
        }
      ],
      "name" => name
    }
  end

  def strip_exif_data(content_type, file) do
    settings = Application.get_env(:pleroma, Pleroma.Upload)
    do_strip = Keyword.fetch!(settings, :strip_exif)
    [filetype, ext] = String.split(content_type, "/")

    if filetype == "image" and do_strip == true do
      Mogrify.open(file) |> Mogrify.custom("strip") |> Mogrify.save(in_place: true)
    end
  end

  def upload_path do
    settings = Application.get_env(:pleroma, Pleroma.Upload)
    Keyword.fetch!(settings, :uploads)
  end

  defp create_name(uuid, ext, type) do
    case type do
      "application/octet-stream" ->
        String.downcase(Enum.join([uuid, ext], "."))

      "audio/mpeg" ->
        String.downcase(Enum.join([uuid, "mp3"], "."))

      _ ->
        String.downcase(Enum.join([uuid, List.last(String.split(type, "/"))], "."))
    end
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
      unless String.contains?(file.filename, ".") do
        case type do
          "image/png" -> file.filename <> ".png"
          "image/jpeg" -> file.filename <> ".jpg"
          "image/gif" -> file.filename <> ".gif"
          "video/webm" -> file.filename <> ".webm"
          "video/mp4" -> file.filename <> ".mp4"
          "audio/mpeg" -> file.filename <> ".mp3"
          "audio/ogg" -> file.filename <> ".ogg"
          "audio/wav" -> file.filename <> ".wav"
          _ -> file.filename
        end
      else
        file.filename
      end
    end
  end

  defp get_upload_path(uuid, should_dedupe) do
    if should_dedupe do
      upload_path()
    else
      Path.join(upload_path(), uuid)
    end
  end

  defp get_url(name, uuid, should_dedupe) do
    if should_dedupe do
      url_for(:cow_uri.urlencode(name))
    else
      url_for(Path.join(uuid, :cow_uri.urlencode(name)))
    end
  end

  defp url_for(file) do
    "#{Web.base_url()}/media/#{file}"
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
            "audio/ogg"

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
end
