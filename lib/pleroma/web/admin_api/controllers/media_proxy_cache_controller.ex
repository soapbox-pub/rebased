# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.ApiSpec.Admin, as: Spec
  alias Pleroma.Web.MediaProxy

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:media_proxy_caches"], admin: true} when action in [:index]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:media_proxy_caches"], admin: true} when action in [:purge, :delete]
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
    |> Cachex.export!()
    |> filter_urls(params[:query])
  end

  defp filter_urls(entries, query) when is_binary(query) do
    for {_, url, _, _, _} <- entries, String.contains?(url, query), do: url
  end

  defp filter_urls(entries, _) do
    Enum.map(entries, fn {_, url, _, _, _} -> url end)
  end

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
