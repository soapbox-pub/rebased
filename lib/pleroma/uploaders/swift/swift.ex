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
    token = Pleroma.Uploaders.Swift.Keystone.get_token()

    case put("#{filename}", body, "X-Auth-Token": token, "Content-Type": content_type) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        # lgtm
        ""

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        # bad token
        ""

      {:error, _} ->
        # bad news
        ""
    end
  end
end
