# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Router.Helpers

  plug(:put_layout, :static_fe)
  plug(:put_view, Pleroma.Web.StaticFE.StaticFEView)
  plug(:assign_id)
  action_fallback(:not_found)

  defp get_title(%Object{data: %{"name" => name}}) when is_binary(name),
    do: name

  defp get_title(%Object{data: %{"summary" => summary}}) when is_binary(summary),
    do: summary

  defp get_title(_), do: nil

  def get_counts(%Activity{} = activity) do
    %Object{data: data} = Object.normalize(activity)

    %{
      likes: data["like_count"] || 0,
      replies: data["repliesCount"] || 0,
      announces: data["announcement_count"] || 0
    }
  end

  def represent(%Activity{object: %Object{data: data}} = activity, selected) do
    {:ok, user} = User.get_or_fetch(activity.object.data["actor"])

    link =
      if user.local do
        Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity)
      else
        data["url"] || data["external_url"] || data["id"]
      end

    %{
      user: user,
      title: get_title(activity.object),
      content: data["content"] || nil,
      attachment: data["attachment"],
      link: link,
      published: data["published"],
      sensitive: data["sensitive"],
      selected: selected,
      counts: get_counts(activity)
    }
  end

  def show_notice(%{assigns: %{notice_id: notice_id}} = conn, _params) do
    instance_name = Pleroma.Config.get([:instance, :name], "Pleroma")
    activity = Activity.get_by_id_with_object(notice_id)
    context = activity.object.data["context"]
    activities = ActivityPub.fetch_activities_for_context(context, %{})

    represented =
      for a <- Enum.reverse(activities) do
        represent(a, a.object.id == activity.object.id)
      end

    render(conn, "conversation.html", %{activities: represented, instance_name: instance_name})
  end

  def show_user(%{assigns: %{username_or_id: username_or_id}} = conn, _params) do
    instance_name = Pleroma.Config.get([:instance, :name], "Pleroma")
    %User{} = user = User.get_cached_by_nickname_or_id(username_or_id)

    timeline =
      for activity <- ActivityPub.fetch_user_activities(user, nil, %{}) do
        represent(activity, false)
      end

    render(conn, "profile.html", %{user: user, timeline: timeline, instance_name: instance_name})
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
