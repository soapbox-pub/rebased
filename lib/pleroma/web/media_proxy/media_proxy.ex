# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy do
  alias Pleroma.Config
  alias Pleroma.Upload
  alias Pleroma.Web
  alias Pleroma.Web.MediaProxy.Invalidation

  @base64_opts [padding: false]

  @spec in_banned_urls(String.t()) :: boolean()
  def in_banned_urls(url), do: elem(Cachex.exists?(:banned_urls_cache, url(url)), 1)

  def remove_from_banned_urls(urls) when is_list(urls) do
    Cachex.execute!(:banned_urls_cache, fn cache ->
      Enum.each(Invalidation.prepare_urls(urls), &Cachex.del(cache, &1))
    end)
  end

  def remove_from_banned_urls(url) when is_binary(url) do
    Cachex.del(:banned_urls_cache, url(url))
  end

  def put_in_banned_urls(urls) when is_list(urls) do
    Cachex.execute!(:banned_urls_cache, fn cache ->
      Enum.each(Invalidation.prepare_urls(urls), &Cachex.put(cache, &1, true))
    end)
  end

  def put_in_banned_urls(url) when is_binary(url) do
    Cachex.put(:banned_urls_cache, url(url), true)
  end

  def url(url) when is_nil(url) or url == "", do: nil
  def url("/" <> _ = url), do: url

  def url(url) do
    if disabled?() or not url_proxiable?(url) do
      url
    else
      encode_url(url)
    end
  end

  @spec url_proxiable?(String.t()) :: boolean()
  def url_proxiable?(url) do
    if local?(url) or whitelisted?(url) do
      false
    else
      true
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
