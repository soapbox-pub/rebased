defmodule Pleroma.Uploaders.Local do
  @behaviour Pleroma.Uploaders.Uploader

  alias Pleroma.Web

  def put_file(name, uuid, tmpfile, _content_type, should_dedupe) do
    upload_folder = get_upload_path(uuid, should_dedupe)
    url_path = get_url(name, uuid, should_dedupe)

    File.mkdir_p!(upload_folder)

    result_file = Path.join(upload_folder, name)

    if File.exists?(result_file) do
      File.rm!(tmpfile)
    else
      File.cp!(tmpfile, result_file)
    end

    {:ok, url_path}
  end

  def upload_path do
    settings = Application.get_env(:pleroma, Pleroma.Uploaders.Local)
    Keyword.fetch!(settings, :uploads)
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
    settings = Application.get_env(:pleroma, Pleroma.Uploaders.Local)

    Keyword.get(settings, :uploads_url)
    |> String.replace("{{file}}", file)
    |> String.replace("{{base_url}}", Web.base_url())
  end
end
