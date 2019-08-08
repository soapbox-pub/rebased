# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy do
  alias Pleroma.Config
  alias Pleroma.Upload
  alias Pleroma.Web

  @base64_opts [padding: false]

  def url(url) when is_nil(url) or url == "", do: nil
  def url("/" <> _ = url), do: url

  def url(url) do
    if disabled?() or local?(url) or whitelisted?(url) do
      url
    else
      encode_url(url)
    end
  end

  defp disabled?, do: !Config.get([:media_proxy, :enabled], false)

  defp local?(url), do: String.starts_with?(url, Pleroma.Web.base_url())

  defp whitelisted?(url) do
    %{host: domain} = URI.parse(url)

    mediaproxy_whitelist = Config.get([:media_proxy, :whitelist])

    upload_base_url_domain =
      if !is_nil(Config.get([Upload, :base_url])) do
        [URI.parse(Config.get([Upload, :base_url])).host]
      else
        []
      end

    whitelist = mediaproxy_whitelist ++ upload_base_url_domain

    Enum.any?(whitelist, fn pattern ->
      String.equivalent?(domain, pattern)
    end)
  end

  def encode_url(url) do
    base64 = Base.url_encode64(url, @base64_opts)

    sig64 =
      base64
      |> signed_url
      |> Base.url_encode64(@base64_opts)

    build_url(sig64, base64, filename(url))
  end

  def decode_url(sig, url) do
    with {:ok, sig} <- Base.url_decode64(sig, @base64_opts),
         signature when signature == sig <- signed_url(url) do
      {:ok, Base.url_decode64!(url, @base64_opts)}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp signed_url(url) do
    :crypto.hmac(:sha, Config.get([Web.Endpoint, :secret_key_base]), url)
  end

  def filename(url_or_path) do
    if path = URI.parse(url_or_path).path, do: Path.basename(path)
  end

  def build_url(sig_base64, url_base64, filename \\ nil) do
    [
      Pleroma.Config.get([:media_proxy, :base_url], Web.base_url()),
      "proxy",
      sig_base64,
      url_base64,
      filename
    ]
    |> Enum.filter(& &1)
    |> Path.join()
  end
end
