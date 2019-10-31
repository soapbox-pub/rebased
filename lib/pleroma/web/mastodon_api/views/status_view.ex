# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.PollView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MediaProxy

  import Pleroma.Web.ActivityPub.Visibility, only: [get_visibility: 1]

  # TODO: Add cached version.
  defp get_replied_to_activities([]), do: %{}

  defp get_replied_to_activities(activities) do
    activities
    |> Enum.map(fn
      %{data: %{"type" => "Create"}} = activity ->
        object = Object.normalize(activity)
        object && object.data["inReplyTo"] != "" && object.data["inReplyTo"]

      _ ->
        nil
    end)
    |> Enum.filter(& &1)
    |> Activity.create_by_object_ap_id_with_object()
    |> Repo.all()
    |> Enum.reduce(%{}, fn activity, acc ->
      object = Object.normalize(activity)
      if object, do: Map.put(acc, object.data["id"], activity), else: acc
    end)
  end

  defp get_user(ap_id) do
    cond do
      user = User.get_cached_by_ap_id(ap_id) ->
        user

      user = User.get_by_guessed_nickname(ap_id) ->
        user

      true ->
        User.error_user(ap_id)
    end
  end

  defp get_context_id(%{data: %{"context_id" => context_id}}) when not is_nil(context_id),
    do: context_id

  defp get_context_id(%{data: %{"context" => context}}) when is_binary(context),
    do: Utils.context_to_conversation_id(context)

  defp get_context_id(_), do: nil

  defp reblogged?(activity, user) do
    object = Object.normalize(activity) || %{}
    present?(user && user.ap_id in (object.data["announcements"] || []))
  end

  def render("index.json", opts) do
    replied_to_activities = get_replied_to_activities(opts.activities)
    opts = Map.put(opts, :replied_to_activities, replied_to_activities)

    safe_render_many(opts.activities, StatusView, "show.json", opts)
  end

  def render(
        "show.json",
        %{activity: %{data: %{"type" => "Announce", "object" => _object}} = activity} = opts
      ) do
    user = get_user(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])
    activity_object = Object.normalize(activity)

    reblogged_activity =
      Activity.create_by_object_ap_id(activity_object.data["id"])
      |> Activity.with_preloaded_bookmark(opts[:for])
      |> Activity.with_set_thread_muted_field(opts[:for])
      |> Repo.one()

    reblogged = render("show.json", Map.put(opts, :activity, reblogged_activity))

    favorited = opts[:for] && opts[:for].ap_id in (activity_object.data["likes"] || [])

    bookmarked = Activity.get_bookmark(reblogged_activity, opts[:for]) != nil

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    %{
      id: to_string(activity.id),
      uri: activity_object.data["id"],
      url: activity_object.data["id"],
      account: AccountView.render("show.json", %{user: user, for: opts[:for]}),
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      reblog: reblogged,
      content: reblogged[:content] || "",
      created_at: created_at,
      reblogs_count: 0,
      replies_count: 0,
      favourites_count: 0,
      reblogged: reblogged?(reblogged_activity, opts[:for]),
      favourited: present?(favorited),
      bookmarked: present?(bookmarked),
      muted: false,
      pinned: pinned?(activity, user),
      sensitive: false,
      spoiler_text: "",
      visibility: get_visibility(activity),
      media_attachments: reblogged[:media_attachments] || [],
      mentions: mentions,
      tags: reblogged[:tags] || [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: [],
      pleroma: %{
        local: activity.local
      }
    }
  end

  def render("show.json", %{activity: %{data: %{"object" => _object}} = activity} = opts) do
    object = Object.normalize(activity)

    user = get_user(activity.data["actor"])
    user_follower_address = user.follower_address

    like_count = object.data["like_count"] || 0
    announcement_count = object.data["announcement_count"] || 0

    tags = object.data["tag"] || []
    sensitive = object.data["sensitive"] || Enum.member?(tags, "nsfw")

    tag_mentions =
      tags
      |> Enum.filter(fn tag -> is_map(tag) and tag["type"] == "Mention" end)
      |> Enum.map(fn tag -> tag["href"] end)

    mentions =
      (object.data["to"] ++ tag_mentions)
      |> Enum.uniq()
      |> Enum.map(fn
        Pleroma.Constants.as_public() -> nil
        ^user_follower_address -> nil
        ap_id -> User.get_cached_by_ap_id(ap_id)
      end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    favorited = opts[:for] && opts[:for].ap_id in (object.data["likes"] || [])

    bookmarked = Activity.get_bookmark(activity, opts[:for]) != nil

    client_posted_this_activity = opts[:for] && user.id == opts[:for].id

    expires_at =
      with true <- client_posted_this_activity,
           expiration when not is_nil(expiration) <-
             ActivityExpiration.get_by_activity_id(activity.id) do
        expiration.scheduled_at
      end

    thread_muted? =
      case activity.thread_muted? do
        thread_muted? when is_boolean(thread_muted?) -> thread_muted?
        nil -> (opts[:for] && CommonAPI.thread_muted?(opts[:for], activity)) || false
      end

    attachment_data = object.data["attachment"] || []
    attachments = render_many(attachment_data, StatusView, "attachment.json", as: :attachment)

    created_at = Utils.to_masto_date(object.data["published"])

    reply_to = get_reply_to(activity, opts)

    reply_to_user = reply_to && get_user(reply_to.data["actor"])

    content =
      object
      |> render_content()

    content_html =
      content
      |> HTML.get_cached_scrubbed_html_for_activity(
        User.html_filter_policy(opts[:for]),
        activity,
        "mastoapi:content"
      )

    content_plaintext =
      content
      |> HTML.get_cached_stripped_html_for_activity(
        activity,
        "mastoapi:content"
      )

    summary = object.data["summary"] || ""

    summary_html =
      summary
      |> HTML.get_cached_scrubbed_html_for_activity(
        User.html_filter_policy(opts[:for]),
        activity,
        "mastoapi:summary"
      )

    summary_plaintext =
      summary
      |> HTML.get_cached_stripped_html_for_activity(
        activity,
        "mastoapi:summary"
      )

    card = render("card.json", Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity))

    url =
      if user.local do
        Pleroma.Web.Router.Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity)
      else
        object.data["url"] || object.data["external_url"] || object.data["id"]
      end

    direct_conversation_id =
      with {_, nil} <- {:direct_conversation_id, opts[:direct_conversation_id]},
           {_, true} <- {:include_id, opts[:with_direct_conversation_id]},
           {_, %User{} = for_user} <- {:for_user, opts[:for]},
           %{data: %{"context" => context}} when is_binary(context) <- activity,
           %Conversation{} = conversation <- Conversation.get_for_ap_id(context),
           %Participation{id: participation_id} <-
             Participation.for_user_and_conversation(for_user, conversation) do
        participation_id
      else
        {:direct_conversation_id, participation_id} when is_integer(participation_id) ->
          participation_id

        _e ->
          nil
      end

    %{
      id: to_string(activity.id),
      uri: object.data["id"],
      url: url,
      account: AccountView.render("show.json", %{user: user, for: opts[:for]}),
      in_reply_to_id: reply_to && to_string(reply_to.id),
      in_reply_to_account_id: reply_to_user && to_string(reply_to_user.id),
      reblog: nil,
      card: card,
      content: content_html,
      created_at: created_at,
      reblogs_count: announcement_count,
      replies_count: object.data["repliesCount"] || 0,
      favourites_count: like_count,
      reblogged: reblogged?(activity, opts[:for]),
      favourited: present?(favorited),
      bookmarked: present?(bookmarked),
      muted: thread_muted? || User.mutes?(opts[:for], user),
      pinned: pinned?(activity, user),
      sensitive: sensitive,
      spoiler_text: summary_html,
      visibility: get_visibility(object),
      media_attachments: attachments,
      poll: render(PollView, "show.json", object: object, for: opts[:for]),
      mentions: mentions,
      tags: build_tags(tags),
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: build_emojis(object.data["emoji"]),
      pleroma: %{
        local: activity.local,
        conversation_id: get_context_id(activity),
        in_reply_to_account_acct: reply_to_user && reply_to_user.nickname,
        content: %{"text/plain" => content_plaintext},
        spoiler_text: %{"text/plain" => summary_plaintext},
        expires_at: expires_at,
        direct_conversation_id: direct_conversation_id,
        thread_muted: thread_muted?
      }
    }
  end

  def render("show.json", _) do
    nil
  end

  def render("card.json", %{rich_media: rich_media, page_url: page_url}) do
    page_url_data = URI.parse(page_url)

    page_url_data =
      if rich_media[:url] != nil do
        URI.merge(page_url_data, URI.parse(rich_media[:url]))
      else
        page_url_data
      end

    page_url = page_url_data |> to_string

    image_url =
      if rich_media[:image] != nil do
        URI.merge(page_url_data, URI.parse(rich_media[:image]))
        |> to_string
      else
        nil
      end

    site_name = rich_media[:site_name] || page_url_data.host

    %{
      type: "link",
      provider_name: site_name,
      provider_url: page_url_data.scheme <> "://" <> page_url_data.host,
      url: page_url,
      image: image_url |> MediaProxy.url(),
      title: rich_media[:title] || "",
      description: rich_media[:description] || "",
      pleroma: %{
        opengraph: rich_media
      }
    }
  end

  def render("card.json", _), do: nil

  def render("attachment.json", %{attachment: attachment}) do
    [attachment_url | _] = attachment["url"]
    media_type = attachment_url["mediaType"] || attachment_url["mimeType"] || "image"
    href = attachment_url["href"] |> MediaProxy.url()

    type =
      cond do
        String.contains?(media_type, "image") -> "image"
        String.contains?(media_type, "video") -> "video"
        String.contains?(media_type, "audio") -> "audio"
        true -> "unknown"
      end

    <<hash_id::signed-32, _rest::binary>> = :crypto.hash(:md5, href)

    %{
      id: to_string(attachment["id"] || hash_id),
      url: href,
      remote_url: href,
      preview_url: href,
      text_url: href,
      type: type,
      description: attachment["name"],
      pleroma: %{mime_type: media_type}
    }
  end

  def render("listen.json", %{activity: %Activity{data: %{"type" => "Listen"}} = activity} = opts) do
    object = Object.normalize(activity)

    user = get_user(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])

    %{
      id: activity.id,
      account: AccountView.render("show.json", %{user: user, for: opts[:for]}),
      created_at: created_at,
      title: object.data["title"] |> HTML.strip_tags(),
      artist: object.data["artist"] |> HTML.strip_tags(),
      album: object.data["album"] |> HTML.strip_tags(),
      length: object.data["length"]
    }
  end

  def render("listens.json", opts) do
    safe_render_many(opts.activities, StatusView, "listen.json", opts)
  end

  def render("context.json", %{activity: activity, activities: activities, user: user}) do
    %{ancestors: ancestors, descendants: descendants} =
      activities
      |> Enum.reverse()
      |> Enum.group_by(fn %{id: id} -> if id < activity.id, do: :ancestors, else: :descendants end)
      |> Map.put_new(:ancestors, [])
      |> Map.put_new(:descendants, [])

    %{
      ancestors: render("index.json", for: user, activities: ancestors, as: :activity),
      descendants: render("index.json", for: user, activities: descendants, as: :activity)
    }
  end

  def get_reply_to(activity, %{replied_to_activities: replied_to_activities}) do
    object = Object.normalize(activity)

    with nil <- replied_to_activities[object.data["inReplyTo"]] do
      # If user didn't participate in the thread
      Activity.get_in_reply_to_activity(activity)
    end
  end

  def get_reply_to(%{data: %{"object" => _object}} = activity, _) do
    object = Object.normalize(activity)

    if object.data["inReplyTo"] && object.data["inReplyTo"] != "" do
      Activity.get_create_by_object_ap_id(object.data["inReplyTo"])
    else
      nil
    end
  end

  def render_content(%{data: %{"type" => "Video"}} = object) do
    with name when not is_nil(name) and name != "" <- object.data["name"] do
      "<p><a href=\"#{object.data["id"]}\">#{name}</a></p>#{object.data["content"]}"
    else
      _ -> object.data["content"] || ""
    end
  end

  def render_content(%{data: %{"type" => object_type}} = object)
      when object_type in ["Article", "Page"] do
    with summary when not is_nil(summary) and summary != "" <- object.data["name"],
         url when is_bitstring(url) <- object.data["url"] do
      "<p><a href=\"#{url}\">#{summary}</a></p>#{object.data["content"]}"
    else
      _ -> object.data["content"] || ""
    end
  end

  def render_content(object), do: object.data["content"] || ""

  @doc """
  Builds a dictionary tags.

  ## Examples

  iex> Pleroma.Web.MastodonAPI.StatusView.build_tags(["fediverse", "nextcloud"])
  [{"name": "fediverse", "url": "/tag/fediverse"},
   {"name": "nextcloud", "url": "/tag/nextcloud"}]

  """
  @spec build_tags(list(any())) :: list(map())
  def build_tags(object_tags) when is_list(object_tags) do
    object_tags = for tag when is_binary(tag) <- object_tags, do: tag

    Enum.reduce(object_tags, [], fn tag, tags ->
      tags ++ [%{name: tag, url: "/tag/#{URI.encode(tag)}"}]
    end)
  end

  def build_tags(_), do: []

  @doc """
  Builds list emojis.

  Arguments: `nil` or list tuple of name and url.

  Returns list emojis.

  ## Examples

  iex> Pleroma.Web.MastodonAPI.StatusView.build_emojis([{"2hu", "corndog.png"}])
  [%{shortcode: "2hu", static_url: "corndog.png", url: "corndog.png", visible_in_picker: false}]

  """
  @spec build_emojis(nil | list(tuple())) :: list(map())
  def build_emojis(nil), do: []

  def build_emojis(emojis) do
    emojis
    |> Enum.map(fn {name, url} ->
      name = HTML.strip_tags(name)

      url =
        url
        |> HTML.strip_tags()
        |> MediaProxy.url()

      %{shortcode: name, url: url, static_url: url, visible_in_picker: false}
    end)
  end

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(_), do: true

  defp pinned?(%Activity{id: id}, %User{pinned_activities: pinned_activities}),
    do: id in pinned_activities
end
