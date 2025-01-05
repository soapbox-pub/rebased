# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.FollowRequestController do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:follows"]})

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaFollowRequestOperation

  @doc "GET /api/v1/pleroma/outgoing_follow_requests"
  def index(%{assigns: %{user: follower}} = conn, _params) do
    follow_requests = User.get_outgoing_follow_requests(follower)

    render(conn, "index.json", for: follower, users: follow_requests, as: :user)
  end
end
