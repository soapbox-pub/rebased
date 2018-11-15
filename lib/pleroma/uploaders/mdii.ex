defmodule Pleroma.Uploaders.Mdii do
  @behaviour Pleroma.Uploaders.Uploader

  @httpoison Application.get_env(:pleroma, :httpoison)

  def put_file(name, uuid, path, content_type, _should_dedupe) do
    settings = Application.get_env(:pleroma, Pleroma.Uploaders.Mdii)
    host_name = Keyword.fetch!(settings, :host_name)

    {:ok, file_data} = File.read(path)

    File.rm!(path)
    
    extension = Regex.replace(~r/^image\//, content_type, "")
    query = "https://#{host_name}/mdii.cgi?#{extension}"

    with {:ok, %{status_code: 200, body: body}} <-
           @httpoison.post(query, file_data) do
      remote_file_name = body
      public_url = "https://#{host_name}/#{remote_file_name}.#{extension}"
      {:ok, public_url}
    end
  end
end
