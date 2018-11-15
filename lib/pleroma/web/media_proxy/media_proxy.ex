defmodule Pleroma.Web.MediaProxy do
  @base64_opts [padding: false]

  def url(nil), do: nil

  def url(url = "/" <> _), do: url

  def url(url) do
    config = Application.get_env(:pleroma, :media_proxy, [])

    if !Keyword.get(config, :enabled, false) or String.starts_with?(url, Pleroma.Web.base_url()) do
      url
    else
      secret = Application.get_env(:pleroma, Pleroma.Web.Endpoint)[:secret_key_base]
      base64 = Base.url_encode64(url, @base64_opts)
      sig = :crypto.hmac(:sha, secret, base64)
      sig64 = sig |> Base.url_encode64(@base64_opts)
      filename = Path.basename(URI.parse(url).path)

      Keyword.get(config, :base_url, Pleroma.Web.base_url()) <>
        "/proxy/#{sig64}/#{base64}/#{filename}"
    end
  end

  def decode_url(sig, url) do
    secret = Application.get_env(:pleroma, Pleroma.Web.Endpoint)[:secret_key_base]
    sig = Base.url_decode64!(sig, @base64_opts)
    local_sig = :crypto.hmac(:sha, secret, url)

    if local_sig == sig do
      {:ok, Base.url_decode64!(url, @base64_opts)}
    else
      {:error, :invalid_signature}
    end
  end
end
