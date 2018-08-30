defmodule Pleroma.Uploaders.Swift.Client do
  use HTTPoison.Base

  @settings Application.get_env(:pleroma, Pleroma.Uploaders.Swift)

  def process_url(url) do
    Enum.join(
      [Keyword.fetch!(@settings, :storage_url), url],
      "/"
    )
  end

  def upload_file(filename, body, content_type) do
    object_url = Keyword.fetch!(@settings, :object_url)
    token = Pleroma.Uploaders.Swift.Keystone.get_token()

    case put("#{filename}", body, "X-Auth-Token": token, "Content-Type": content_type) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        {:ok, "#{object_url}/#{filename}"}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, "Unauthorized, Bad Token"}

      {:error, _} ->
        {:error, "Swift Upload Error"}
    end
  end
end
