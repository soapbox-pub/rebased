# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.RelayController do
  use Pleroma.Web, :controller

  alias Pleroma.ModerationLog
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:follows"]}
    when action in [:follow, :unfollow]
  )

  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action == :index)

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.RelayOperation

  def index(conn, _params) do
    with {:ok, list} <- Relay.list() do
      json(conn, %{relays: list})
    end
  end

  def follow(%{assigns: %{user: admin}, body_params: %{relay_url: target}} = conn, _) do
    with {:ok, _message} <- Relay.follow(target) do
      ModerationLog.insert_log(%{action: "relay_follow", actor: admin, target: target})

      json(conn, %{actor: target, followed_back: target in Relay.following()})
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end

  def unfollow(%{assigns: %{user: admin}, body_params: %{relay_url: target} = params} = conn, _) do
    with {:ok, _message} <- Relay.unfollow(target, %{force: params[:force]}) do
      ModerationLog.insert_log(%{action: "relay_unfollow", actor: admin, target: target})

      json(conn, target)
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end
end
