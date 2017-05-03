defmodule Pleroma.Web.OStatus.ActivityRepresenter do
  alias Pleroma.{Activity, User}
  alias Pleroma.Web.OStatus.UserRepresenter
  require Logger

  defp get_in_reply_to(%{"object" => %{ "inReplyTo" => in_reply_to}}) do
    [{:"thr:in-reply-to", [ref: to_charlist(in_reply_to)], []}]
  end

  defp get_in_reply_to(_), do: []

  defp get_mentions(to) do
    Enum.map(to, fn (id) ->
      cond do
        # Special handling for the AP/Ostatus public collections
        "https://www.w3.org/ns/activitystreams#Public" == id ->
          {:link, [rel: "mentioned", "ostatus:object-type": "http://activitystrea.ms/schema/1.0/collection", href: "http://activityschema.org/collection/public"], []}
        # Ostatus doesn't handle follower collections, ignore these.
        Regex.match?(~r/^#{Pleroma.Web.base_url}.+followers$/, id) ->
          []
        true ->
          {:link, [rel: "mentioned", "ostatus:object-type": "http://activitystrea.ms/schema/1.0/person", href: id], []}
      end
    end)
  end

  def to_simple_form(activity, user, with_author \\ false)
  def to_simple_form(%{data: %{"object" => %{"type" => "Note"}}} = activity, user, with_author) do
    h = fn(str) -> [to_charlist(str)] end

    updated_at = activity.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = activity.inserted_at
    |> NaiveDateTime.to_iso8601

    attachments = Enum.map(activity.data["object"]["attachment"] || [], fn(attachment) ->
      url = hd(attachment["url"])
      {:link, [rel: 'enclosure', href: to_charlist(url["href"]), type: to_charlist(url["mediaType"])], []}
    end)

    in_reply_to = get_in_reply_to(activity.data)
    author = if with_author, do: [{:author, UserRepresenter.to_simple_form(user)}], else: []
    mentions = activity.data["to"] |> get_mentions

    [
      {:"activity:object-type", ['http://activitystrea.ms/schema/1.0/note']},
      {:"activity:verb", ['http://activitystrea.ms/schema/1.0/post']},
      {:id, h.(activity.data["object"]["id"])}, # For notes, federate the object id.
      {:title, ['New note by #{user.nickname}']},
      {:content, [type: 'html'], h.(activity.data["object"]["content"])},
      {:published, h.(inserted_at)},
      {:updated, h.(updated_at)},
      {:"ostatus:conversation", [], h.(activity.data["context"])},
      {:link, [href: h.(activity.data["context"]), rel: 'ostatus:conversation'], []}
    ] ++ attachments ++ in_reply_to ++ author ++ mentions
  end

  def to_simple_form(%{data: %{"type" => "Like"}} = activity, user, with_author) do
    h = fn(str) -> [to_charlist(str)] end

    updated_at = activity.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = activity.inserted_at
    |> NaiveDateTime.to_iso8601

    in_reply_to = get_in_reply_to(activity.data)
    author = if with_author, do: [{:author, UserRepresenter.to_simple_form(user)}], else: []
    mentions = activity.data["to"] |> get_mentions

    [
      {:"activity:verb", ['http://activitystrea.ms/schema/1.0/favorite']},
      {:id, h.(activity.data["id"])},
      {:title, ['New favorite by #{user.nickname}']},
      {:content, [type: 'html'], ['#{user.nickname} favorited something']},
      {:published, h.(inserted_at)},
      {:updated, h.(updated_at)},
      {:"activity:object", [
        {:"activity:object-type", ['http://activitystrea.ms/schema/1.0/note']},
        {:id, h.(activity.data["object"])}, # For notes, federate the object id.
      ]},
      {:"ostatus:conversation", [], h.(activity.data["context"])},
      {:link, [href: h.(activity.data["context"]), rel: 'ostatus:conversation'], []},
      {:"thr:in-reply-to", [ref: to_charlist(activity.data["object"])], []}
    ] ++ author ++ mentions
  end

  def to_simple_form(%{data: %{"type" => "Announce"}} = activity, user, with_author) do
    h = fn(str) -> [to_charlist(str)] end

    updated_at = activity.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = activity.inserted_at
    |> NaiveDateTime.to_iso8601

    in_reply_to = get_in_reply_to(activity.data)
    author = if with_author, do: [{:author, UserRepresenter.to_simple_form(user)}], else: []

    retweeted_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])
    retweeted_user = User.get_cached_by_ap_id(retweeted_activity.data["actor"])

    retweeted_xml = to_simple_form(retweeted_activity, retweeted_user)

    mentions = activity.data["to"] |> get_mentions
    [
      {:"activity:verb", ['http://activitystrea.ms/schema/1.0/share']},
      {:id, h.(activity.data["id"])},
      {:title, ['#{user.nickname} repeated a notice']},
      {:content, [type: 'html'], ['RT #{retweeted_activity.data["object"]["content"]}']},
      {:published, h.(inserted_at)},
      {:updated, h.(updated_at)},
      {:"ostatus:conversation", [], h.(activity.data["context"])},
      {:link, [href: h.(activity.data["context"]), rel: 'ostatus:conversation'], []},
      {:"thr:in-reply-to", [ref: to_charlist(activity.data["object"])], []},
      {:"activity:object", retweeted_xml}
    ] ++ mentions ++ author
  end

  def wrap_with_entry(simple_form) do
    [{
      :entry, [
        xmlns: 'http://www.w3.org/2005/Atom',
        "xmlns:thr": 'http://purl.org/syndication/thread/1.0',
        "xmlns:activity": 'http://activitystrea.ms/spec/1.0/',
        "xmlns:poco": 'http://portablecontacts.net/spec/1.0',
        "xmlns:ostatus": 'http://ostatus.org/schema/1.0'
      ], simple_form
    }]
  end

  def to_simple_form(_,_,_), do: nil
end
