defmodule Pleroma.Web.MediaProxy do
  @base64_opts [padding: false]
  @base64_key Application.get_env(:pleroma, Pleroma.Web.Endpoint)[:secret_key_base]

  def url(nil), do: nil

  def url(url) do
    if String.starts_with?(url, Pleroma.Web.base_url) do
      url
    else
      base64 = Base.url_encode64(url, @base64_opts)
      sig = :crypto.hmac(:sha, @base64_key, base64)
      sig64 = sig |> Base.url_encode64(@base64_opts)
      cache_url("#{sig64}/#{base64}")
    end
  end

  def decode_url(sig, url) do
    sig = Base.url_decode64!(sig, @base64_opts)
    local_sig = :crypto.hmac(:sha, @base64_key, url)
    if local_sig == sig do
      {:ok, Base.url_decode64!(url, @base64_opts)}
    else
      {:error, :invalid_signature}
    end
  end

  defp cache_url(path) do
    "/proxy/" <> path
  end


end
