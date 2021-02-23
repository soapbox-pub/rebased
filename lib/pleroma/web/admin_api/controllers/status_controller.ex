# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:read:statuses"]} when action in [:index, :show])

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:statuses"]} when action in [:update, :delete]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.StatusOperation

  def index(%{assigns: %{user: _admin}} = conn, params) do
    activities =
      ActivityPub.fetch_statuses(nil, %{
        godmode: params.godmode,
        local_only: params.local_only,
        limit: params.page_size,
        offset: (params.page - 1) * params.page_size,
        exclude_reblogs: not params.with_reblogs
      })

    render(conn, "index.json", activities: activities, as: :activity)
  end

  def show(conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id) do
      render(conn, "show.json", %{activity: activity})
    else
      nil -> {:error, :not_found}
    end
  end

  def update(%{assigns: %{user: admin}, body_params: params} = conn, %{id: id}) do
    with {:ok, activity} <- CommonAPI.update_activity_scope(id, params) do
      ModerationLog.insert_log(%{
        action: "status_update",
        actor: admin,
        subject: activity,
        sensitive: params[:sensitive],
        visibility: params[:visibility]
      })

      conn
      |> put_view(MastodonAPI.StatusView)
      |> render("show.json", %{activity: activity})
    end
  end

  def delete(%{assigns: %{user: user}} = conn, %{id: id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      ModerationLog.insert_log(%{
        action: "status_delete",
        actor: user,
        subject_id: id
      })

      json(conn, %{})
    end
  end
end
