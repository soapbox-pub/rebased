# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FollowRequestController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  plug(:put_view, Pleroma.Web.MastodonAPI.AccountView)
  plug(:assign_follower when action != :index)

  action_fallback(:errors)

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:follows"]} when action == :index)

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]} when action != :index
  )

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "GET /api/v1/follow_requests"
  def index(%{assigns: %{user: followed}} = conn, _params) do
    follow_requests = User.get_follow_requests(followed)

    render(conn, "index.json", for: followed, users: follow_requests, as: :user)
  end

  @doc "POST /api/v1/follow_requests/:id/authorize"
  def authorize(%{assigns: %{user: followed, follower: follower}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.accept_follow_request(follower, followed) do
      render(conn, "relationship.json", user: followed, target: follower)
    end
  end

  @doc "POST /api/v1/follow_requests/:id/reject"
  def reject(%{assigns: %{user: followed, follower: follower}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.reject_follow_request(follower, followed) do
      render(conn, "relationship.json", user: followed, target: follower)
    end
  end

  defp assign_follower(%{params: %{"id" => id}} = conn, _) do
    case User.get_cached_by_id(id) do
      %User{} = follower -> assign(conn, :follower, follower)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end

  defp errors(conn, {:error, message}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: message})
  end
end
