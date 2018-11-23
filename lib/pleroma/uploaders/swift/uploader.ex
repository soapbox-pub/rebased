defmodule Pleroma.Uploaders.Swift do
  @behaviour Pleroma.Uploaders.Uploader

  def get_file(name) do
    {:ok, {:url, Path.join([Pleroma.Config.get!([__MODULE__, :object_url]), name])}}
  end

  def put_file(name, uuid, tmp_path, content_type, _opts) do
    {:ok, file_data} = File.read(tmp_path)
    remote_name = "#{uuid}/#{name}"

    Pleroma.Uploaders.Swift.Client.upload_file(remote_name, file_data, content_type)
  end
end
