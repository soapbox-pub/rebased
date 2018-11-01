defmodule Pleroma.Web.MastodonAPI.StatusView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.{AccountView, StatusView}
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Repo
  alias Pleroma.HTML

  # TODO: Add cached version.
  defp get_replied_to_activities(activities) do
    activities
    |> Enum.map(fn
      %{data: %{"type" => "Create", "object" => %{"inReplyTo" => inReplyTo}}} ->
        inReplyTo != "" && inReplyTo

      _ ->
        nil
    end)
    |> Enum.filter(& &1)
    |> Activity.create_activity_by_object_id_query()
    |> Repo.all()
    |> Enum.reduce(%{}, fn activity, acc ->
      Map.put(acc, activity.data["object"]["id"], activity)
    end)
  end

  def render("index.json", opts) do
    replied_to_activities = get_replied_to_activities(opts.activities)

    render_many(
      opts.activities,
      StatusView,
      "status.json",
      Map.put(opts, :replied_to_activities, replied_to_activities)
    )
    |> Enum.filter(fn x -> not is_nil(x) end)
  end

  def render(
        "status.json",
        %{activity: %{data: %{"type" => "Announce", "object" => object}} = activity} = opts
      ) do
    user = User.get_cached_by_ap_id(activity.data["actor"])
    created_at = Utils.to_masto_date(activity.data["published"])

    reblogged = Activity.get_create_activity_by_object_ap_id(object)
    reblogged = render("status.json", Map.put(opts, :activity, reblogged))

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    %{
      id: to_string(activity.id),
      uri: object,
      url: object,
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      reblog: reblogged,
      content: reblogged[:content],
      created_at: created_at,
      reblogs_count: 0,
      replies_count: 0,
      favourites_count: 0,
      reblogged: false,
      favourited: false,
      muted: false,
      sensitive: false,
      spoiler_text: "",
      visibility: "public",
      media_attachments: [],
      mentions: mentions,
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: []
    }
  end

  def render("status.json", %{activity: %{data: %{"object" => object}} = activity} = opts) do
    user = User.get_cached_by_ap_id(activity.data["actor"])

    like_count = object["like_count"] || 0
    announcement_count = object["announcement_count"] || 0

    tags = object["tag"] || []
    sensitive = object["sensitive"] || Enum.member?(tags, "nsfw")

    mentions =
      activity.recipients
      |> Enum.map(fn ap_id -> User.get_cached_by_ap_id(ap_id) end)
      |> Enum.filter(& &1)
      |> Enum.map(fn user -> AccountView.render("mention.json", %{user: user}) end)

    repeated = opts[:for] && opts[:for].ap_id in (object["announcements"] || [])
    favorited = opts[:for] && opts[:for].ap_id in (object["likes"] || [])

    attachment_data = object["attachment"] || []
    attachment_data = attachment_data ++ if object["type"] == "Video", do: [object], else: []
    attachments = render_many(attachment_data, StatusView, "attachment.json", as: :attachment)

    created_at = Utils.to_masto_date(object["published"])

    reply_to = get_reply_to(activity, opts)
    reply_to_user = reply_to && User.get_cached_by_ap_id(reply_to.data["actor"])

    emojis =
      (activity.data["object"]["emoji"] || [])
      |> Enum.map(fn {name, url} ->
        name = HTML.strip_tags(name)

        url =
          HTML.strip_tags(url)
          |> MediaProxy.url()

        %{shortcode: name, url: url, static_url: url, visible_in_picker: false}
      end)

    content =
      render_content(object)
      |> HTML.filter_tags(User.html_filter_policy(opts[:for]))

    %{
      id: to_string(activity.id),
      uri: object["id"],
      url: object["external_url"] || object["id"],
      account: AccountView.render("account.json", %{user: user}),
      in_reply_to_id: reply_to && to_string(reply_to.id),
      in_reply_to_account_id: reply_to_user && to_string(reply_to_user.id),
      reblog: nil,
      content: content,
      created_at: created_at,
      reblogs_count: announcement_count,
      replies_count: 0,
      favourites_count: like_count,
      reblogged: !!repeated,
      favourited: !!favorited,
      muted: false,
      sensitive: sensitive,
      spoiler_text: object["summary"] || "",
      visibility: get_visibility(object),
      media_attachments: attachments |> Enum.take(4),
      mentions: mentions,
      # fix,
      tags: [],
      application: %{
        name: "Web",
        website: nil
      },
      language: nil,
      emojis: emojis
    }
  end

  def render("status.json", _) do
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
      description: attachment["name"]
    }
  end

  def get_reply_to(activity, %{replied_to_activities: replied_to_activities}) do
    _id = activity.data["object"]["inReplyTo"]
    replied_to_activities[activity.data["object"]["inReplyTo"]]
  end

  def get_reply_to(%{data: %{"object" => object}}, _) do
    if object["inReplyTo"] && object["inReplyTo"] != "" do
      Activity.get_create_activity_by_object_ap_id(object["inReplyTo"])
    else
      nil
    end
  end

  def get_visibility(object) do
    public = "https://www.w3.org/ns/activitystreams#Public"
    to = object["to"] || []
    cc = object["cc"] || []

    cond do
      public in to ->
        "public"

      public in cc ->
        "unlisted"

      # this should use the sql for the object's activity
      Enum.any?(to, &String.contains?(&1, "/followers")) ->
        "private"

      true ->
        "direct"
    end
  end

  def render_content(%{"type" => "Video"} = object) do
    name = object["name"]

    content =
      if !!name and name != "" do
        "<p><a href=\"#{object["id"]}\">#{name}</a></p>#{object["content"]}"
      else
        object["content"]
      end

    content
  end

  def render_content(%{"type" => "Article"} = object) do
    summary = object["name"]

    content =
      if !!summary and summary != "" and is_bitstring(object["url"]) do
        "<p><a href=\"#{object["url"]}\">#{summary}</a></p>#{object["content"]}"
      else
        object["content"]
      end

    content
  end

  def render_content(object), do: object["content"]
end
