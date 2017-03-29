defmodule Pleroma.Upload do
  def store(%Plug.Upload{} = file) do
    uuid = Ecto.UUID.generate
    upload_folder = Path.join(upload_path(), uuid)
    File.mkdir_p!(upload_folder)
    result_file = Path.join(upload_folder, file.filename)
    File.cp!(file.path, result_file)

    %{
      "type" => "Image",
      "href" => url_for(Path.join(uuid, file.filename)),
      "name" => file.filename,
      "uuid" => uuid
    }
  end

  defp upload_path do
    Application.get_env(:pleroma, Pleroma.Upload)
    |> Keyword.fetch!(:uploads)
  end

  defp url_for(file) do
    host =
      Application.get_env(:pleroma, Pleroma.Web.Endpoint)
      |> Keyword.fetch!(:url)
      |> Keyword.fetch!(:host)

    protocol = Application.get_env(:pleroma, Pleroma.Web.Endpoint) |> Keyword.fetch!(:protocol)

    "#{protocol}://#{host}/media/#{file}"
  end
end
