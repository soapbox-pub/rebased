# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.AdminAPI.ReportView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView

  @parent_types ~w{Like Announce EmojiReact}

  def render("index.json", %{notifications: notifications, for: reading_user} = opts) do
    activities = Enum.map(notifications, & &1.activity)

    parent_activities =
      activities
      |> Enum.filter(fn
        %{data: %{"type" => type}} ->
          type in @parent_types
      end)
      |> Enum.map(& &1.data["object"])
      |> Activity.create_by_object_ap_id()
      |> Activity.with_preloaded_object(:left)
      |> Pleroma.Repo.all()

    relationships_opt =
      cond do
        Map.has_key?(opts, :relationships) ->
          opts[:relationships]

        is_nil(reading_user) ->
          UserRelationship.view_relationships_option(nil, [])

        true ->
          move_activities_targets =
            activities
            |> Enum.filter(&(&1.data["type"] == "Move"))
            |> Enum.map(&User.get_cached_by_ap_id(&1.data["target"]))
            |> Enum.filter(& &1)

          actors =
            activities
            |> Enum.map(fn a -> User.get_cached_by_ap_id(a.data["actor"]) end)
            |> Enum.filter(& &1)
            |> Kernel.++(move_activities_targets)

          UserRelationship.view_relationships_option(reading_user, actors, subset: :source_mutes)
      end

    opts =
      opts
      |> Map.put(:parent_activities, parent_activities)
      |> Map.put(:relationships, relationships_opt)

    safe_render_many(notifications, NotificationView, "show.json", opts)
  end

  def render(
        "show.json",
        %{
          notification: %Notification{activity: activity} = notification,
          for: reading_user
        } = opts
      ) do
    actor = User.get_cached_by_ap_id(activity.data["actor"])

    parent_activity_fn = fn ->
      if opts[:parent_activities] do
        Activity.Queries.find_by_object_ap_id(opts[:parent_activities], activity.data["object"])
      else
        Activity.get_create_by_object_ap_id(activity.data["object"])
      end
    end

    # Note: :relationships contain user mutes (needed for :muted flag in :status)
    status_render_opts = %{relationships: opts[:relationships]}
    account = AccountView.render("show.json", %{user: actor, for: reading_user})

    response = %{
      id: to_string(notification.id),
      type: notification.type,
      created_at: CommonAPI.Utils.to_masto_date(notification.inserted_at),
      account: account,
      pleroma: %{
        is_muted: User.mutes?(reading_user, actor),
        is_seen: notification.seen
      }
    }

    case notification.type do
      "mention" ->
        put_status(response, activity, reading_user, status_render_opts)

      "status" ->
        put_status(response, activity, reading_user, status_render_opts)

      "favourite" ->
        put_status(response, parent_activity_fn.(), reading_user, status_render_opts)

      "reblog" ->
        put_status(response, parent_activity_fn.(), reading_user, status_render_opts)

      "move" ->
        put_target(response, activity, reading_user, %{})

      "poll" ->
        put_status(response, activity, reading_user, status_render_opts)

      "pleroma:emoji_reaction" ->
        response
        |> put_status(parent_activity_fn.(), reading_user, status_render_opts)
        |> put_emoji(activity)

      "pleroma:chat_mention" ->
        put_chat_message(response, activity, reading_user, status_render_opts)

      "pleroma:report" ->
        put_report(response, activity)

      type when type in ["follow", "follow_request"] ->
        response
    end
  end

  defp put_report(response, activity) do
    report_render = ReportView.render("show.json", Report.extract_report_info(activity))

    Map.put(response, :report, report_render)
  end

  defp put_emoji(response, activity) do
    Map.put(response, :emoji, activity.data["content"])
  end

  defp put_chat_message(response, activity, reading_user, opts) do
    object = Object.normalize(activity, fetch: false)
    author = User.get_cached_by_ap_id(object.data["actor"])
    chat = Pleroma.Chat.get(reading_user.id, author.ap_id)
    cm_ref = MessageReference.for_chat_and_object(chat, object)
    render_opts = Map.merge(opts, %{for: reading_user, chat_message_reference: cm_ref})
    chat_message_render = MessageReferenceView.render("show.json", render_opts)

    Map.put(response, :chat_message, chat_message_render)
  end

  defp put_status(response, activity, reading_user, opts) do
    status_render_opts = Map.merge(opts, %{activity: activity, for: reading_user})
    status_render = StatusView.render("show.json", status_render_opts)

    Map.put(response, :status, status_render)
  end

  defp put_target(response, activity, reading_user, opts) do
    target_user = User.get_cached_by_ap_id(activity.data["target"])
    target_render_opts = Map.merge(opts, %{user: target_user, for: reading_user})
    target_render = AccountView.render("show.json", target_render_opts)

    Map.put(response, :target, target_render)
  end
end
