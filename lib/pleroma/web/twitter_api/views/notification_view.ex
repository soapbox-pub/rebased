# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.NotificationView do
  use Pleroma.Web, :view
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.UserView

  require Pleroma.Constants

  defp get_user(ap_id, opts) do
    cond do
      user = opts[:users][ap_id] ->
        user

      String.ends_with?(ap_id, "/followers") ->
        nil

      ap_id == Pleroma.Constants.as_public() ->
        nil

      true ->
        User.get_cached_by_ap_id(ap_id)
    end
  end

  def render("notification.json", %{notifications: notifications, for: user}) do
    render_many(
      notifications,
      Pleroma.Web.TwitterAPI.NotificationView,
      "notification.json",
      for: user
    )
  end

  def render(
        "notification.json",
        %{
          notification: %Notification{
            id: id,
            seen: seen,
            activity: activity,
            inserted_at: created_at
          },
          for: user
        } = opts
      ) do
    ntype =
      case activity.data["type"] do
        "Create" -> "mention"
        "Like" -> "like"
        "Announce" -> "repeat"
        "Follow" -> "follow"
      end

    from = get_user(activity.data["actor"], opts)

    %{
      "id" => id,
      "ntype" => ntype,
      "notice" => ActivityView.render("activity.json", %{activity: activity, for: user}),
      "from_profile" => UserView.render("show.json", %{user: from, for: user}),
      "is_seen" => if(seen, do: 1, else: 0),
      "created_at" => created_at |> Utils.format_naive_asctime()
    }
  end
end
