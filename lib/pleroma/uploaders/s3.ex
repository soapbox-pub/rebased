defmodule Pleroma.Uploaders.S3 do
  alias Pleroma.Web.MediaProxy

  @behaviour Pleroma.Uploaders.Uploader

  def put_file(name, uuid, path, content_type, _should_dedupe) do
    settings = Application.get_env(:pleroma, Pleroma.Uploaders.S3)
    bucket = Keyword.fetch!(settings, :bucket)
    public_endpoint = Keyword.fetch!(settings, :public_endpoint)
    force_media_proxy = Keyword.fetch!(settings, :force_media_proxy)

    {:ok, file_data} = File.read(path)

    File.rm!(path)

    s3_name = "#{uuid}/#{encode(name)}"

    {:ok, _} =
      ExAws.S3.put_object(bucket, s3_name, file_data, [
        {:acl, :public_read},
        {:content_type, content_type}
      ])
      |> ExAws.request()

    url_base = "#{public_endpoint}/#{bucket}/#{s3_name}"

    public_url =
      if force_media_proxy do
        MediaProxy.url(url_base)
      else
        url_base
      end

    {:ok, public_url}
  end

  defp encode(name) do
    String.replace(name, ~r/[^0-9a-zA-Z!.*'()_-]/, "-")
  end
end
