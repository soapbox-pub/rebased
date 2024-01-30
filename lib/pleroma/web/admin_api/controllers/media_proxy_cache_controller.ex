# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.ApiSpec.Admin, as: Spec
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:media_proxy_caches"]} when action in [:index]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:media_proxy_caches"]} when action in [:purge, :delete]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Spec.MediaProxyCacheOperation

  def index(%{assigns: %{user: _}} = conn, params) do
    entries = fetch_entries(params)
    urls = paginate_entries(entries, params.page, params.page_size)

    render(conn, "index.json",
      urls: urls,
      page_size: params.page_size,
      count: length(entries)
    )
  end

  defp fetch_entries(params) do
    MediaProxy.cache_table()
    |> @cachex.stream!(Cachex.Query.create(true, :key))
    |> filter_entries(params[:query])
  end

  defp filter_entries(stream, query) when is_binary(query) do
    regex = ~r/#{query}/i

    stream
    |> Enum.filter(fn url -> String.match?(url, regex) end)
    |> Enum.to_list()
  end

  defp filter_entries(stream, _), do: Enum.to_list(stream)

  defp paginate_entries(entries, page, page_size) do
    offset = page_size * (page - 1)
    Enum.slice(entries, offset, page_size)
  end

  def delete(%{assigns: %{user: _}, body_params: %{urls: urls}} = conn, _) do
    MediaProxy.remove_from_banned_urls(urls)
    json(conn, %{})
  end

  def purge(%{assigns: %{user: _}, body_params: %{urls: urls, ban: ban}} = conn, _) do
    MediaProxy.Invalidation.purge(urls)

    if ban do
      MediaProxy.put_in_banned_urls(urls)
    end

    json(conn, %{})
  end
end
