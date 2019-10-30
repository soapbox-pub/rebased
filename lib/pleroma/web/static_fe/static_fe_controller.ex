# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.StaticFE.ActivityRepresenter
  alias Pleroma.Web.StaticFE.UserRepresenter

  plug(:put_layout, :static_fe)
  plug(:put_view, Pleroma.Web.StaticFE.StaticFEView)
  plug(:assign_id)
  action_fallback(:not_found)

  def show_notice(%{assigns: %{notice_id: notice_id}} = conn, _params) do
    with {:ok, data} <- ActivityRepresenter.represent(notice_id) do
      context = data.object.data["context"]
      activities = ActivityPub.fetch_activities_for_context(context, %{})

      data =
        for a <- Enum.reverse(activities) do
          ActivityRepresenter.prepare_activity(data.user, a)
          |> Map.put(:selected, a.object.id == data.object.id)
        end

      render(conn, "conversation.html", data: data)
    end
  end

  def show_user(%{assigns: %{username_or_id: username_or_id}} = conn, _params) do
    with {:ok, data} <- UserRepresenter.represent(username_or_id) do
      render(conn, "profile.html", data: data)
    end
  end

  def assign_id(%{path_info: ["notice", notice_id]} = conn, _opts),
    do: assign(conn, :notice_id, notice_id)

  def assign_id(%{path_info: ["users", user_id]} = conn, _opts),
    do: assign(conn, :username_or_id, user_id)

  def assign_id(%{path_info: [user_id]} = conn, _opts),
    do: assign(conn, :username_or_id, user_id)

  def assign_id(conn, _opts), do: conn

  # Fallback for unhandled types
  def not_found(conn, _opts) do
    conn
    |> put_status(404)
    |> text("Not found")
  end
end
