# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.ActivityView do
  use Pleroma.Web, :view
  alias Pleroma.Activity
  alias Pleroma.Formatter
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter
  alias Pleroma.Web.TwitterAPI.UserView

  import Ecto.Query
  require Logger
  require Pleroma.Constants

  defp query_context_ids([]), do: []

  defp query_context_ids(contexts) do
    query = from(o in Object, where: fragment("(?)->>'id' = ANY(?)", o.data, ^contexts))

    Repo.all(query)
  end

  defp query_users([]), do: []

  defp query_users(user_ids) do
    query = from(user in User, where: user.ap_id in ^user_ids)

    Repo.all(query)
  end

  defp collect_context_ids(activities) do
    _contexts =
      activities
      |> Enum.reject(& &1.data["context_id"])
      |> Enum.map(fn %{data: data} ->
        data["context"]
      end)
      |> Enum.filter(& &1)
      |> query_context_ids()
      |> Enum.reduce(%{}, fn %{data: %{"id" => ap_id}, id: id}, acc ->
        Map.put(acc, ap_id, id)
      end)
  end

  defp collect_users(activities) do
    activities
    |> Enum.map(fn activity ->
      case activity.data do
        data = %{"type" => "Follow"} ->
          [data["actor"], data["object"]]

        data ->
          [data["actor"]]
      end ++ activity.recipients
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> query_users()
    |> Enum.reduce(%{}, fn user, acc ->
      Map.put(acc, user.ap_id, user)
    end)
  end

  defp get_context_id(%{data: %{"context_id" => context_id}}, _) when not is_nil(context_id),
    do: context_id

  defp get_context_id(%{data: %{"context" => nil}}, _), do: nil

  defp get_context_id(%{data: %{"context" => context}}, options) do
    cond do
      id = options[:context_ids][context] -> id
      true -> Utils.context_to_conversation_id(context)
    end
  end

  defp get_context_id(_, _), do: nil

  defp get_user(ap_id, opts) do
    cond do
      user = opts[:users][ap_id] ->
        user

      String.ends_with?(ap_id, "/followers") ->
        nil

      ap_id == Pleroma.Constants.as_public() ->
        nil

      user = User.get_cached_by_ap_id(ap_id) ->
        user

      user = User.get_by_guessed_nickname(ap_id) ->
        user

      true ->
        User.error_user(ap_id)
    end
  end

  def render("index.json", opts) do
    context_ids = collect_context_ids(opts.activities)
    users = collect_users(opts.activities)

    opts =
      opts
      |> Map.put(:context_ids, context_ids)
      |> Map.put(:users, users)

    safe_render_many(
      opts.activities,
      ActivityView,
      "activity.json",
      opts
    )
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Delete"}} = activity} = opts) do
    user = get_user(activity.data["actor"], opts)
    created_at = activity.data["published"] |> Utils.date_to_asctime()

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

  def render("activity.json", %{activity: %{data: %{"type" => "Follow"}} = activity} = opts) do
    user = get_user(activity.data["actor"], opts)
    created_at = activity.data["published"] || DateTime.to_iso8601(activity.inserted_at)
    created_at = created_at |> Utils.date_to_asctime()

    followed = get_user(activity.data["object"], opts)
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

  def render("activity.json", %{activity: %{data: %{"type" => "Announce"}} = activity} = opts) do
    user = get_user(activity.data["actor"], opts)
    created_at = activity.data["published"] |> Utils.date_to_asctime()
    announced_activity = Activity.get_create_by_object_ap_id(activity.data["object"])

    text = "#{user.nickname} repeated a status."

    retweeted_status = render("activity.json", Map.merge(opts, %{activity: announced_activity}))

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
      "statusnet_conversation_id" => get_context_id(announced_activity, opts),
      "external_url" => activity.data["id"],
      "activity_type" => "repeat"
    }
  end

  def render("activity.json", %{activity: %{data: %{"type" => "Like"}} = activity} = opts) do
    user = get_user(activity.data["actor"], opts)
    liked_activity = Activity.get_create_by_object_ap_id(activity.data["object"])
    liked_activity_id = if liked_activity, do: liked_activity.id, else: nil

    created_at =
      activity.data["published"]
      |> Utils.date_to_asctime()

    text = "#{user.nickname} favorited a status."

    favorited_status =
      if liked_activity,
        do: render("activity.json", Map.merge(opts, %{activity: liked_activity})),
        else: nil

    %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=Favourite",
      "created_at" => created_at,
      "favorited_status" => favorited_status,
      "in_reply_to_status_id" => liked_activity_id,
      "external_url" => activity.data["id"],
      "activity_type" => "like"
    }
  end

  def render(
        "activity.json",
        %{activity: %{data: %{"type" => "Create", "object" => object_id}} = activity} = opts
      ) do
    user = get_user(activity.data["actor"], opts)

    object = Object.normalize(object_id)

    created_at = object.data["published"] |> Utils.date_to_asctime()
    like_count = object.data["like_count"] || 0
    announcement_count = object.data["announcement_count"] || 0
    favorited = opts[:for] && opts[:for].ap_id in (object.data["likes"] || [])
    repeated = opts[:for] && opts[:for].ap_id in (object.data["announcements"] || [])
    pinned = activity.id in user.info.pinned_activities

    attentions =
      []
      |> Utils.maybe_notify_to_recipients(activity)
      |> Utils.maybe_notify_mentioned_recipients(activity)
      |> Enum.map(fn ap_id -> get_user(ap_id, opts) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> UserView.render("show.json", %{user: user, for: opts[:for]}) end)

    conversation_id = get_context_id(activity, opts)

    tags = object.data["tag"] || []
    possibly_sensitive = object.data["sensitive"] || Enum.member?(tags, "nsfw")

    tags = if possibly_sensitive, do: Enum.uniq(["nsfw" | tags]), else: tags

    {summary, content} = render_content(object.data)

    html =
      content
      |> HTML.get_cached_scrubbed_html_for_activity(
        User.html_filter_policy(opts[:for]),
        activity,
        "twitterapi:content"
      )
      |> Formatter.emojify(object.data["emoji"])

    text =
      if content do
        content
        |> String.replace(~r/<br\s?\/?>/, "\n")
        |> HTML.get_cached_stripped_html_for_activity(activity, "twitterapi:content")
      else
        ""
      end

    reply_parent = Activity.get_in_reply_to_activity(activity)

    reply_user = reply_parent && User.get_cached_by_ap_id(reply_parent.actor)

    summary = HTML.strip_tags(summary)

    card =
      StatusView.render(
        "card.json",
        Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
      )

    thread_muted? =
      case activity.thread_muted? do
        thread_muted? when is_boolean(thread_muted?) -> thread_muted?
        nil -> CommonAPI.thread_muted?(user, activity)
      end

    %{
      "id" => activity.id,
      "uri" => object.data["id"],
      "user" => UserView.render("show.json", %{user: user, for: opts[:for]}),
      "statusnet_html" => html,
      "text" => text,
      "is_local" => activity.local,
      "is_post_verb" => true,
      "created_at" => created_at,
      "in_reply_to_status_id" => reply_parent && reply_parent.id,
      "in_reply_to_screen_name" => reply_user && reply_user.nickname,
      "in_reply_to_profileurl" => User.profile_url(reply_user),
      "in_reply_to_ostatus_uri" => reply_user && reply_user.ap_id,
      "in_reply_to_user_id" => reply_user && reply_user.id,
      "statusnet_conversation_id" => conversation_id,
      "attachments" => (object.data["attachment"] || []) |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions,
      "fave_num" => like_count,
      "repeat_num" => announcement_count,
      "favorited" => !!favorited,
      "repeated" => !!repeated,
      "pinned" => pinned,
      "external_url" => object.data["external_url"] || object.data["id"],
      "tags" => tags,
      "activity_type" => "post",
      "possibly_sensitive" => possibly_sensitive,
      "visibility" => Pleroma.Web.ActivityPub.Visibility.get_visibility(object),
      "summary" => summary,
      "summary_html" => summary |> Formatter.emojify(object.data["emoji"]),
      "card" => card,
      "muted" => thread_muted? || User.mutes?(opts[:for], user)
    }
  end

  def render("activity.json", %{activity: unhandled_activity}) do
    Logger.warn("#{__MODULE__} unhandled activity: #{inspect(unhandled_activity)}")
    nil
  end

  def render_content(%{"type" => "Note"} = object) do
    summary = object["summary"]

    content =
      if !!summary and summary != "" do
        "<p>#{summary}</p>#{object["content"]}"
      else
        object["content"]
      end

    {summary, content}
  end

  def render_content(%{"type" => object_type} = object)
      when object_type in ["Article", "Page", "Video"] do
    summary = object["name"] || object["summary"]

    content =
      if !!summary and summary != "" and is_bitstring(object["url"]) do
        "<p><a href=\"#{object["url"]}\">#{summary}</a></p>#{object["content"]}"
      else
        object["content"]
      end

    {summary, content}
  end

  def render_content(object) do
    summary = object["summary"] || "Unhandled activity type: #{object["type"]}"
    content = "<p>#{summary}</p>#{object["content"]}"

    {summary, content}
  end
end
