defmodule Pleroma.Uploaders.MDII do
  alias Pleroma.Config

  @behaviour Pleroma.Uploaders.Uploader

  @httpoison Application.get_env(:pleroma, :httpoison)

  def put_file(name, uuid, path, content_type, should_dedupe) do
    cgi = Pleroma.Config.get([Pleroma.Uploaders.MDII, :cgi])
    files = Pleroma.Config.get([Pleroma.Uploaders.MDII, :files])

    {:ok, file_data} = File.read(path)

    extension = String.split(name, ".") |> List.last()
    query = "#{cgi}?#{extension}"

    with {:ok, %{status_code: 200, body: body}} <- @httpoison.post(query, file_data) do
      File.rm!(path)
      remote_file_name = String.split(body) |> List.first()
      public_url = "#{files}/#{remote_file_name}.#{extension}"
      {:ok, public_url}
    else
      _ -> Pleroma.Uploaders.Local.put_file(name, uuid, path, content_type, should_dedupe)
    end
  end
end
