defmodule Pleroma.Upload do
  alias Ecto.UUID
  alias Pleroma.Web

  def store(%Plug.Upload{} = file) do
    uuid = UUID.generate()
    upload_folder = Path.join(upload_path(), uuid)
    File.mkdir_p!(upload_folder)
    result_file = Path.join(upload_folder, file.filename)
    File.cp!(file.path, result_file)

    # fix content type on some image uploads
    content_type =
      if file.content_type in [nil, "application/octet-stream"] do
        get_content_type(file.path)
      else
        file.content_type
      end

    %{
      "type" => "Image",
      "url" => [
        %{
          "type" => "Link",
          "mediaType" => content_type,
          "href" => url_for(Path.join(uuid, :cow_uri.urlencode(file.filename)))
        }
      ],
      "name" => file.filename,
      "uuid" => uuid
    }
  end

  def store(%{"img" => "data:image/" <> image_data}) do
    parsed = Regex.named_captures(~r/(?<filetype>jpeg|png|gif);base64,(?<data>.*)/, image_data)
    data = Base.decode64!(parsed["data"])
    uuid = UUID.generate()
    upload_folder = Path.join(upload_path(), uuid)
    File.mkdir_p!(upload_folder)
    filename = Base.encode16(:crypto.hash(:sha256, data)) <> ".#{parsed["filetype"]}"
    result_file = Path.join(upload_folder, filename)

    File.write!(result_file, data)

    content_type = "image/#{parsed["filetype"]}"

    %{
      "type" => "Image",
      "url" => [
        %{
          "type" => "Link",
          "mediaType" => content_type,
          "href" => url_for(Path.join(uuid, :cow_uri.urlencode(filename)))
        }
      ],
      "name" => filename,
      "uuid" => uuid
    }
  end

  defp upload_path do
    settings = Application.get_env(:pleroma, Pleroma.Upload)
    Keyword.fetch!(settings, :uploads)
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
