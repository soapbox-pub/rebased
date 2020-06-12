# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.MediaProxyCacheController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.ApiSpec.Admin, as: Spec

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

  def index(%{assigns: %{user: _}} = conn, _) do
    render(conn, "index.json", urls: [])
  end

  def delete(%{assigns: %{user: _}, body_params: %{urls: urls}} = conn, _) do
    render(conn, "index.json", urls: urls)
  end

  def purge(%{assigns: %{user: _}, body_params: %{urls: urls, ban: _ban}} = conn, _) do
    render(conn, "index.json", urls: urls)
  end
end
