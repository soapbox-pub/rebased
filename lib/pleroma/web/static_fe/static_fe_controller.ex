# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Metadata
  alias Pleroma.Web.Router.Helpers

  plug(:put_layout, :static_fe)
  plug(:put_view, Pleroma.Web.StaticFE.StaticFEView)
  plug(:assign_id)

  @page_keys ["max_id", "min_id", "limit", "since_id", "order"]

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

  def represent(%Activity{} = activity), do: represent(activity, false)

  def represent(%Activity{object: %Object{data: data}} = activity, selected) do
    {:ok, user} = User.get_or_fetch(activity.object.data["actor"])

    link =
      case user.local do
        true -> Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity)
        _ -> data["url"] || data["external_url"] || data["id"]
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
      counts: get_counts(activity),
      id: activity.id
    }
  end

  def show(%{assigns: %{notice_id: notice_id}} = conn, _params) do
    with %Activity{local: true} = activity <-
           Activity.get_by_id_with_object(notice_id),
         true <- Visibility.is_public?(activity.object),
         %User{} = user <- User.get_by_ap_id(activity.object.data["actor"]) do
      meta = Metadata.build_tags(%{activity_id: notice_id, object: activity.object, user: user})

      timeline =
        activity.object.data["context"]
        |> ActivityPub.fetch_activities_for_context(%{})
        |> Enum.reverse()
        |> Enum.map(&represent(&1, &1.object.id == activity.object.id))

      render(conn, "conversation.html", %{activities: timeline, meta: meta})
    else
      _ ->
        conn
        |> put_status(404)
        |> render("error.html", %{message: "Post not found.", meta: ""})
    end
  end

  def show(%{assigns: %{username_or_id: username_or_id}} = conn, params) do
    case User.get_cached_by_nickname_or_id(username_or_id) do
      %User{} = user ->
        meta = Metadata.build_tags(%{user: user})

        timeline =
          ActivityPub.fetch_user_activities(user, nil, Map.take(params, @page_keys))
          |> Enum.map(&represent/1)

        prev_page_id =
          (params["min_id"] || params["max_id"]) &&
            List.first(timeline) && List.first(timeline).id

        next_page_id = List.last(timeline) && List.last(timeline).id

        render(conn, "profile.html", %{
          user: user,
          timeline: timeline,
          prev_page_id: prev_page_id,
          next_page_id: next_page_id,
          meta: meta
        })

      _ ->
        conn
        |> put_status(404)
        |> render("error.html", %{message: "User not found.", meta: ""})
    end
  end

  def assign_id(%{path_info: ["notice", notice_id]} = conn, _opts),
    do: assign(conn, :notice_id, notice_id)

  def assign_id(%{path_info: ["users", user_id]} = conn, _opts),
    do: assign(conn, :username_or_id, user_id)

  def assign_id(conn, _opts), do: conn
end
