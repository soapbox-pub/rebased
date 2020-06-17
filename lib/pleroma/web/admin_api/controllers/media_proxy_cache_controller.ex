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
    cursor =
      :banned_urls_cache
      |> :ets.table([{:traverse, {:select, Cachex.Query.create(true, :key)}}])
      |> :qlc.cursor()

    urls =
      case params.page do
        1 ->
          :qlc.next_answers(cursor, params.page_size)

        _ ->
          :qlc.next_answers(cursor, (params.page - 1) * params.page_size)
          :qlc.next_answers(cursor, params.page_size)
      end

    :qlc.delete_cursor(cursor)

    render(conn, "index.json", urls: urls)
  end

  def delete(%{assigns: %{user: _}, body_params: %{urls: urls}} = conn, _) do
    MediaProxy.remove_from_banned_urls(urls)
    render(conn, "index.json", urls: urls)
  end

  def purge(%{assigns: %{user: _}, body_params: %{urls: urls, ban: ban}} = conn, _) do
    MediaProxy.Invalidation.purge(urls)

    if ban do
      MediaProxy.put_in_banned_urls(urls)
    end

    render(conn, "index.json", urls: urls)
  end
end
