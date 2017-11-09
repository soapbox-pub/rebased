defmodule Pleroma.Upload do
  alias Ecto.UUID
  alias Pleroma.Web
  def store(%Plug.Upload{} = file) do
    uuid = UUID.generate
    upload_folder = Path.join(upload_path(), uuid)
    File.mkdir_p!(upload_folder)
    result_file = Path.join(upload_folder, file.filename)
    File.cp!(file.path, result_file)

    # fix content type on some image uploads
    matches = Regex.named_captures(~r/\.(?<ext>(jpg|jpeg|png|gif))$/i, file.filename)
    content_type = if file.content_type == "application/octet-stream" and matches do
      if matches["ext"] == "jpg", do: "image/jpeg", else: "image/#{matches["ext"]}"
    else
      file.content_type
    end

    %{
      "type" => "Image",
      "url" => [%{
        "type" => "Link",
        "mediaType" => content_type,
        "href" => url_for(Path.join(uuid, :cow_uri.urlencode(file.filename)))
      }],
      "name" => file.filename,
      "uuid" => uuid
    }
  end

  def store(%{"img" => "data:image/" <> image_data}) do
    parsed = Regex.named_captures(~r/(?<filetype>jpeg|png|gif);base64,(?<data>.*)/, image_data)
    data = Base.decode64!(parsed["data"])
    uuid = UUID.generate
    upload_folder = Path.join(upload_path(), uuid)
    File.mkdir_p!(upload_folder)
    filename = Base.encode16(:crypto.hash(:sha256, data)) <> ".#{parsed["filetype"]}"
    result_file = Path.join(upload_folder, filename)

    File.write!(result_file, data)

    content_type = "image/#{parsed["filetype"]}"

    %{
      "type" => "Image",
      "url" => [%{
        "type" => "Link",
        "mediaType" => content_type,
        "href" => url_for(Path.join(uuid, :cow_uri.urlencode(filename)))
      }],
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
end
