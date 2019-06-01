# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MediaProxy

  import Pleroma.Web.ActivityPub.Visibility, only: [get_visibility: 1]

  # TODO: Add cached version.
  defp get_replied_to_activities(activities) do
    activities
    |> Enum.map(fn
      %{data: %{"type" => "Create", "object" => object}} ->
        object = Object.normalize(object)
        object.data["inReplyTo"] != "" && object.data["inReplyTo"]

      _ ->
        nil
    end)
    |> Enum.filter(& &1)
    |> Activity.create_by_object_ap_id()
    |> Repo.all()
    |> Enum.reduce(%{}, fn activity, acc ->
      object = Object.normalize(activity)
      Map.put(acc, object.data["id"], activity)
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

    opts.activities
    |> safe_render_many(
      StatusView,
      "status.json",
      Map.put(opts, :replied_to_activities, replied_to_activities)
    )
  end

  def render(
        "status.json",
        %{activity: %{data: %{"type" => "Announce", "object" => _object}} = activity} = opts
      ) do
    user = get_user(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])
    activity_object = Object.normalize(activity)

    reblogged_activity =
      Activity.create_by_object_ap_id(activity_object.data["id"])
      |> Activity.with_preloaded_bookmark(opts[:for])
      |> Repo.one()

    reblogged = render("status.json", Map.put(opts, :activity, reblogged_activity))

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
      account: AccountView.render("account.json", %{user: user}),
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
      visibility: "public",
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

  def render("status.json", %{activity: %{data: %{"object" => _object}} = activity} = opts) do
    object = Object.normalize(activity)

    user = get_user(activity.data["actor"])

    like_count = object.data["like_count"] || 0
    announcement_count = object.data["announcement_count"] || 0

    tags = object.data["tag"] || []
    sensitive = object.data["sensitive"] || Enum.member?(tags, "nsfw")

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    favorited = opts[:for] && opts[:for].ap_id in (object.data["likes"] || [])

    bookmarked = Activity.get_bookmark(activity, opts[:for]) != nil

    thread_muted? =
      case activity.thread_muted? do
        thread_muted? when is_boolean(thread_muted?) -> thread_muted?
        nil -> CommonAPI.thread_muted?(user, activity)
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
        object.data["external_url"] || object.data["id"]
      end

    %{
      id: to_string(activity.id),
      uri: object.data["id"],
      url: url,
      account: AccountView.render("account.json", %{user: user}),
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
      poll: render("poll.json", %{object: object, for: opts[:for]}),
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
        spoiler_text: %{"text/plain" => summary_plaintext}
      }
    }
  end

  def render("status.json", _) do
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

  def render("card.json", _) do
    nil
  end

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

  # TODO: Add tests for this view
  def render("poll.json", %{object: object} = opts) do
    {multiple, options} =
      case object.data do
        %{"anyOf" => options} when is_list(options) -> {true, options}
        %{"oneOf" => options} when is_list(options) -> {false, options}
        _ -> {nil, nil}
      end

    if options do
      end_time =
        (object.data["closed"] || object.data["endTime"])
        |> NaiveDateTime.from_iso8601!()

      expired =
        end_time
        |> NaiveDateTime.compare(NaiveDateTime.utc_now())
        |> case do
          :lt -> true
          _ -> false
        end

      voted =
        if opts[:for] do
          existing_votes =
            Pleroma.Web.ActivityPub.Utils.get_existing_votes(opts[:for].ap_id, object)

          existing_votes != [] or opts[:for].ap_id == object.data["actor"]
        else
          false
        end

      {options, votes_count} =
        Enum.map_reduce(options, 0, fn %{"name" => name} = option, count ->
          current_count = option["replies"]["totalItems"] || 0

          {%{
             title: HTML.strip_tags(name),
             votes_count: current_count
           }, current_count + count}
        end)

      %{
        # Mastodon uses separate ids for polls, but an object can't have
        # more than one poll embedded so object id is fine
        id: object.id,
        expires_at: Utils.to_masto_date(end_time),
        expired: expired,
        multiple: multiple,
        votes_count: votes_count,
        options: options,
        voted: voted,
        emojis: build_emojis(object.data["emoji"])
      }
    else
      nil
    end
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
      tags ++ [%{name: tag, url: "/tag/#{tag}"}]
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

  defp pinned?(%Activity{id: id}, %User{info: %{pinned_activities: pinned_activities}}),
    do: id in pinned_activities
end
