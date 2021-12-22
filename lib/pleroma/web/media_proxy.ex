# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy do
  alias Pleroma.Config
  alias Pleroma.Helpers.UriHelper
  alias Pleroma.Upload
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MediaProxy.Invalidation

  @base64_opts [padding: false]
  @cache_table :banned_urls_cache

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def cache_table, do: @cache_table

  @spec in_banned_urls(String.t()) :: boolean()
  def in_banned_urls(url), do: elem(@cachex.exists?(@cache_table, url(url)), 1)

  def remove_from_banned_urls(urls) when is_list(urls) do
    @cachex.execute!(@cache_table, fn cache ->
      Enum.each(Invalidation.prepare_urls(urls), &@cachex.del(cache, &1))
    end)
  end

  def remove_from_banned_urls(url) when is_binary(url) do
    @cachex.del(@cache_table, url(url))
  end

  def put_in_banned_urls(urls) when is_list(urls) do
    @cachex.execute!(@cache_table, fn cache ->
      Enum.each(Invalidation.prepare_urls(urls), &@cachex.put(cache, &1, true))
    end)
  end

  def put_in_banned_urls(url) when is_binary(url) do
    @cachex.put(@cache_table, url(url), true)
  end

  def url(url) when is_nil(url) or url == "", do: nil
  def url("/" <> _ = url), do: url

  def url(url) do
    if enabled?() and url_proxiable?(url) do
      encode_url(url)
    else
      url
    end
  end

  @spec url_proxiable?(String.t()) :: boolean()
  def url_proxiable?(url) do
    not local?(url) and not whitelisted?(url)
  end

  def preview_url(url, preview_params \\ []) do
    if preview_enabled?() do
      encode_preview_url(url, preview_params)
    else
      url(url)
    end
  end

  def enabled?, do: Config.get([:media_proxy, :enabled], false)

  # Note: media proxy must be enabled for media preview proxy in order to load all
  #   non-local non-whitelisted URLs through it and be sure that body size constraint is preserved.
  def preview_enabled?, do: enabled?() and !!Config.get([:media_preview_proxy, :enabled])

  def local?(url), do: String.starts_with?(url, Endpoint.url())

  def whitelisted?(url) do
    %{host: domain} = URI.parse(url)

    mediaproxy_whitelist_domains =
      [:media_proxy, :whitelist]
      |> Config.get()
      |> Kernel.++(["#{Upload.base_url()}"])
      |> Enum.map(&maybe_get_domain_from_url/1)

    domain in mediaproxy_whitelist_domains
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

  def encode_preview_url(url, preview_params \\ []) do
    {base64, sig64} = base64_sig64(url)

    build_preview_url(sig64, base64, filename(url), preview_params)
  end

  def decode_url(sig, url) do
    with {:ok, sig} <- Base.url_decode64(sig, @base64_opts),
         signature when signature == sig <- signed_url(url) do
      {:ok, Base.url_decode64!(url, @base64_opts)}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  def decode_url(encoded) do
    [_, "proxy", sig, base64 | _] = URI.parse(encoded).path |> String.split("/")
    decode_url(sig, base64)
  end

  defp signed_url(url) do
    :crypto.mac(:hmac, :sha, Config.get([Endpoint, :secret_key_base]), url)
  end

  def filename(url_or_path) do
    if path = URI.parse(url_or_path).path, do: Path.basename(path)
  end

  def base_url do
    Config.get([:media_proxy, :base_url], Endpoint.url())
  end

  defp proxy_url(path, sig_base64, url_base64, filename) do
    [
      base_url(),
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

  def build_preview_url(sig_base64, url_base64, filename \\ nil, preview_params \\ []) do
    uri = proxy_url("proxy/preview", sig_base64, url_base64, filename)

    UriHelper.modify_uri_params(uri, preview_params)
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
