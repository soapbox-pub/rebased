defmodule Pleroma.Uploaders.Swift do
  @behaviour Pleroma.Uploaders.Uploader

  def put_file(name, uuid, tmp_path, content_type, _should_dedupe) do
    {:ok, file_data} = File.read(tmp_path)
    remote_name = "#{uuid}/#{name}"

    Pleroma.Uploaders.Swift.Client.upload_file(remote_name, file_data, content_type)
  end
end
