# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ScheduledActivityController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.ScheduledActivity
  alias Pleroma.Web.MastodonAPI.MastodonAPI

  plug(:assign_scheduled_activity when action != :index)

  @oauth_read_actions [:show, :index]

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action in @oauth_read_actions)
  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action not in @oauth_read_actions)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc "GET /api/v1/scheduled_statuses"
  def index(%{assigns: %{user: user}} = conn, params) do
    with scheduled_activities <- MastodonAPI.get_scheduled_activities(user, params) do
      conn
      |> add_link_headers(scheduled_activities)
      |> render("index.json", scheduled_activities: scheduled_activities)
    end
  end

  @doc "GET /api/v1/scheduled_statuses/:id"
  def show(%{assigns: %{scheduled_activity: scheduled_activity}} = conn, _params) do
    render(conn, "show.json", scheduled_activity: scheduled_activity)
  end

  @doc "PUT /api/v1/scheduled_statuses/:id"
  def update(%{assigns: %{scheduled_activity: scheduled_activity}} = conn, params) do
    with {:ok, scheduled_activity} <- ScheduledActivity.update(scheduled_activity, params) do
      render(conn, "show.json", scheduled_activity: scheduled_activity)
    end
  end

  @doc "DELETE /api/v1/scheduled_statuses/:id"
  def delete(%{assigns: %{scheduled_activity: scheduled_activity}} = conn, _params) do
    with {:ok, scheduled_activity} <- ScheduledActivity.delete(scheduled_activity) do
      render(conn, "show.json", scheduled_activity: scheduled_activity)
    end
  end

  defp assign_scheduled_activity(%{assigns: %{user: user}, params: %{"id" => id}} = conn, _) do
    case ScheduledActivity.get(user, id) do
      %ScheduledActivity{} = activity -> assign(conn, :scheduled_activity, activity)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end
end
