# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy do
  @base64_opts [padding: false]

  def url(nil), do: nil

  def url(""), do: nil

  def url("/" <> _ = url), do: url

  def url(url) do
    if !enabled?() or local?(url) or whitelisted?(url) do
      url
    else
      encode_url(url)
    end
  end

  defp enabled?, do: Pleroma.Config.get([:media_proxy, :enabled], false)

  defp local?(url), do: String.starts_with?(url, Pleroma.Web.base_url())

  defp whitelisted?(url) do
    %{host: domain} = URI.parse(url)

    Enum.any?(Pleroma.Config.get([:media_proxy, :whitelist]), fn pattern ->
      String.equivalent?(domain, pattern)
    end)
  end

  def encode_url(url) do
    secret = Pleroma.Config.get([Pleroma.Web.Endpoint, :secret_key_base])
    base64 = Base.url_encode64(url, @base64_opts)
    sig = :crypto.hmac(:sha, secret, base64)
    sig64 = sig |> Base.url_encode64(@base64_opts)

    build_url(sig64, base64, filename(url))
  end

  def decode_url(sig, url) do
    secret = Pleroma.Config.get([Pleroma.Web.Endpoint, :secret_key_base])
    sig = Base.url_decode64!(sig, @base64_opts)
    local_sig = :crypto.hmac(:sha, secret, url)

    if local_sig == sig do
      {:ok, Base.url_decode64!(url, @base64_opts)}
    else
      {:error, :invalid_signature}
    end
  end

  def filename(url_or_path) do
    if path = URI.parse(url_or_path).path, do: Path.basename(path)
  end

  def build_url(sig_base64, url_base64, filename \\ nil) do
    [
      Pleroma.Config.get([:media_proxy, :base_url], Pleroma.Web.base_url()),
      "proxy",
      sig_base64,
      url_base64,
      filename
    ]
    |> Enum.filter(fn value -> value end)
    |> Path.join()
  end
end
