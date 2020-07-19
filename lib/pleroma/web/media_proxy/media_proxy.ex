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
    if not enabled?() or not url_proxiable?(url) do
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

  # Note: routing all URLs to preview handler (even local and whitelisted).
  #   Preview handler will call url/1 on decoded URLs, and applicable ones will detour media proxy.
  def preview_url(url) do
    if preview_enabled?() do
      encode_preview_url(url)
    else
      url
    end
  end

  def enabled?, do: Config.get([:media_proxy, :enabled], false)

  # Note: media proxy must be enabled for media preview proxy in order to load all
  #   non-local non-whitelisted URLs through it and be sure that body size constraint is preserved.
  def preview_enabled?, do: enabled?() and Config.get([:media_preview_proxy, :enabled], false)

  def local?(url), do: String.starts_with?(url, Pleroma.Web.base_url())

  def whitelisted?(url) do
    %{host: domain} = URI.parse(url)

    mediaproxy_whitelist_domains =
      [:media_proxy, :whitelist]
      |> Config.get()
      |> Enum.map(&maybe_get_domain_from_url/1)

    whitelist_domains =
      if base_url = Config.get([Upload, :base_url]) do
        %{host: base_domain} = URI.parse(base_url)
        [base_domain | mediaproxy_whitelist_domains]
      else
        mediaproxy_whitelist_domains
      end

    domain in whitelist_domains
  end

  defp maybe_get_domain_from_url("http" <> _ = url) do
    URI.parse(url).host
  end

  defp maybe_get_domain_from_url(domain), do: domain

  defp base64_sig64(url) do
    base64 = Base.url_encode64(url, @base64_opts)

    sig64 =
      base64
      |> signed_url()
      |> Base.url_encode64(@base64_opts)

    {base64, sig64}
  end

  def encode_url(url) do
    {base64, sig64} = base64_sig64(url)

    build_url(sig64, base64, filename(url))
  end

  def encode_preview_url(url) do
    {base64, sig64} = base64_sig64(url)

    build_preview_url(sig64, base64, filename(url))
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

  defp proxy_url(path, sig_base64, url_base64, filename) do
    [
      Config.get([:media_proxy, :base_url], Web.base_url()),
      path,
      sig_base64,
      url_base64,
      filename
    ]
    |> Enum.filter(& &1)
    |> Path.join()
  end

  def build_url(sig_base64, url_base64, filename \\ nil) do
    proxy_url("proxy", sig_base64, url_base64, filename)
  end

  def build_preview_url(sig_base64, url_base64, filename \\ nil) do
    proxy_url("proxy/preview", sig_base64, url_base64, filename)
  end

  def verify_request_path_and_url(
        %Plug.Conn{params: %{"filename" => _}, request_path: request_path},
        url
      ) do
    verify_request_path_and_url(request_path, url)
  end

  def verify_request_path_and_url(request_path, url) when is_binary(request_path) do
    filename = filename(url)

    if filename && not basename_matches?(request_path, filename) do
      {:wrong_filename, filename}
    else
      :ok
    end
  end

  def verify_request_path_and_url(_, _), do: :ok

  defp basename_matches?(path, filename) do
    basename = Path.basename(path)
    basename == filename or URI.decode(basename) == filename or URI.encode(basename) == filename
  end
end
