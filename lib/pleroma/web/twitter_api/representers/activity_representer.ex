# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# THIS MODULE IS DEPRECATED! DON'T USE IT!
# USE THE Pleroma.Web.TwitterAPI.Views.ActivityView MODULE!
defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter
  alias Pleroma.{Activity, User}
  alias Pleroma.Web.TwitterAPI.{TwitterAPI, UserView, ActivityView}
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Formatter
  alias Pleroma.HTML

  defp user_by_ap_id(user_list, ap_id) do
    Enum.find(user_list, fn %{ap_id: user_id} -> ap_id == user_id end)
  end

  def to_map(
        %Activity{data: %{"type" => "Announce", "actor" => actor, "published" => created_at}} =
          activity,
        %{users: users, announced_activity: announced_activity} = opts
      ) do
    user = user_by_ap_id(users, actor)
    created_at = created_at |> Utils.date_to_asctime()

    text = "#{user.nickname} retweeted a status."

    announced_user = user_by_ap_id(users, announced_activity.data["actor"])
    retweeted_status = to_map(announced_activity, Map.merge(%{user: announced_user}, opts))

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=note",
      "created_at" => created_at,
      "retweeted_status" => retweeted_status,
      "statusnet_conversation_id" => conversation_id(announced_activity),
      "external_url" => activity.data["id"],
      "activity_type" => "repeat"
    }
  end

  def to_map(
        %Activity{data: %{"type" => "Like", "published" => created_at}} = activity,
        %{user: user, liked_activity: liked_activity} = opts
      ) do
    created_at = created_at |> Utils.date_to_asctime()

    text = "#{user.nickname} favorited a status."

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=Favourite",
      "created_at" => created_at,
      "in_reply_to_status_id" => liked_activity.id,
      "external_url" => activity.data["id"],
      "activity_type" => "like"
    }
  end

  def to_map(
        %Activity{data: %{"type" => "Follow", "object" => followed_id}} = activity,
        %{user: user} = opts
      ) do
    created_at = activity.data["published"] || DateTime.to_iso8601(activity.inserted_at)
    created_at = created_at |> Utils.date_to_asctime()

    followed = User.get_cached_by_ap_id(followed_id)
    text = "#{user.nickname} started following #{followed.nickname}"

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "attentions" => [],
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
      "external_url" => activity.data["id"],
      "activity_type" => "follow"
    }
  end

  # TODO:
  # Make this more proper. Just a placeholder to not break the frontend.
  def to_map(
        %Activity{
          data: %{"type" => "Undo", "published" => created_at, "object" => undid_activity}
        } = activity,
        %{user: user} = opts
      ) do
    created_at = created_at |> Utils.date_to_asctime()

    text = "#{user.nickname} undid the action at #{undid_activity["id"]}"

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "attentions" => [],
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
      "external_url" => activity.data["id"],
      "activity_type" => "undo"
    }
  end

  def to_map(
        %Activity{data: %{"type" => "Delete", "published" => created_at, "object" => _}} =
          activity,
        %{user: user} = opts
      ) do
    created_at = created_at |> Utils.date_to_asctime()

    %{
      "id" => activity.id,
      "uri" => activity.data["object"],
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "attentions" => [],
      "statusnet_html" => "deleted notice {{tag",
      "text" => "deleted notice {{tag",
      "is_local" => activity.local,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
      "external_url" => activity.data["id"],
      "activity_type" => "delete"
    }
  end

  def to_map(
        %Activity{data: %{"object" => %{"content" => _content} = object}} = activity,
        %{user: user} = opts
      ) do
    created_at = object["published"] |> Utils.date_to_asctime()
    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])
    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])
    pinned = activity.id in user.info.pinned_activities

    mentions = opts[:mentioned] || []

    attentions =
      activity.recipients
      |> Enum.map(fn ap_id -> Enum.find(mentions, fn user -> ap_id == user.ap_id end) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> UserView.render("show.json", %{user: user, for: opts[:for]}) end)

    conversation_id = conversation_id(activity)

    tags = activity.data["object"]["tag"] || []
    possibly_sensitive = activity.data["object"]["sensitive"] || Enum.member?(tags, "nsfw")

    tags = if possibly_sensitive, do: Enum.uniq(["nsfw" | tags]), else: tags

    {_summary, content} = ActivityView.render_content(object)

    html =
      HTML.filter_tags(content, User.html_filter_policy(opts[:for]))
      |> Formatter.emojify(object["emoji"])

    attachments = object["attachment"] || []

    reply_parent = Activity.get_in_reply_to_activity(activity)

    reply_user = reply_parent && User.get_cached_by_ap_id(reply_parent.actor)

    summary = HTML.strip_tags(object["summary"])

    %{
      "id" => activity.id,
      "uri" => activity.data["object"]["id"],
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => html,
      "text" => HTML.strip_tags(content),
      "is_local" => activity.local,
      "is_post_verb" => true,
      "created_at" => created_at,
      "in_reply_to_status_id" => object["inReplyToStatusId"],
      "in_reply_to_screen_name" => reply_user && reply_user.nickname,
      "in_reply_to_profileurl" => User.profile_url(reply_user),
      "in_reply_to_ostatus_uri" => reply_user && reply_user.ap_id,
      "in_reply_to_user_id" => reply_user && reply_user.id,
      "statusnet_conversation_id" => conversation_id,
      "attachments" => attachments |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions,
      "fave_num" => like_count,
      "repeat_num" => announcement_count,
      "favorited" => to_boolean(favorited),
      "repeated" => to_boolean(repeated),
      "pinned" => pinned,
      "external_url" => object["external_url"] || object["id"],
      "tags" => tags,
      "activity_type" => "post",
      "possibly_sensitive" => possibly_sensitive,
      "visibility" => Pleroma.Web.MastodonAPI.StatusView.get_visibility(object),
      "summary" => summary,
      "summary_html" => summary |> Formatter.emojify(object["emoji"])
    }
  end

  def conversation_id(activity) do
    with context when not is_nil(context) <- activity.data["context"] do
      TwitterAPI.context_to_conversation_id(context)
    else
      _e -> nil
    end
  end

  defp to_boolean(false) do
    false
  end

  defp to_boolean(nil) do
    false
  end

  defp to_boolean(_) do
    true
  end
end
