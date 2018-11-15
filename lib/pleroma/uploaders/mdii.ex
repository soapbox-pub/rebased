defmodule Pleroma.Uploaders.Mdii do
  @behaviour Pleroma.Uploaders.Uploader

  def put_file(name, uuid, path, content_type, _should_dedupe) do
    settings = Application.get_env(:pleroma, Pleroma.Uploaders.Mdii)
    host_name = Keyword.fetch!(settings, :host_name)

    {:ok, file_data} = File.read(path)

    File.rm!(path)

    remote_file_name = "00000"
    extension = "png"

    public_url = "https://#{host_name}/#{remote_file_name}.#{extension}"

    {:ok, public_url}
  end
end
