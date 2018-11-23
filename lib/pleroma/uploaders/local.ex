defmodule Pleroma.Uploaders.Local do
  @behaviour Pleroma.Uploaders.Uploader

  alias Pleroma.Web

  def get_file(_) do
    {:ok, {:static_dir, upload_path()}}
  end

  def put_file(name, uuid, tmpfile, _content_type, opts) do
    upload_folder = get_upload_path(uuid, opts.dedupe)

    File.mkdir_p!(upload_folder)

    result_file = Path.join(upload_folder, name)

    if File.exists?(result_file) do
      File.rm!(tmpfile)
    else
      File.cp!(tmpfile, result_file)
    end

    {:ok, {:file, get_url(name, uuid, opts.dedupe)}}
  end

  def upload_path do
    Pleroma.Config.get!([__MODULE__, :uploads])
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
      :cow_uri.urlencode(name)
    else
      Path.join(uuid, :cow_uri.urlencode(name))
    end
  end
end
