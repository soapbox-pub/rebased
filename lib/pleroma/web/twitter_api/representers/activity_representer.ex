defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ObjectRepresenter}
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Activity

  defp user_by_ap_id(user_list, ap_id) do
    Enum.find(user_list, fn (%{ap_id: user_id}) -> ap_id == user_id end)
  end

  def to_map(%Activity{data: %{"type" => "Announce", "actor" => actor}} = activity, %{users: users, announced_activity: announced_activity} = opts) do
    user = user_by_ap_id(users, actor)
    created_at = get_in(activity.data, ["published"])
    |> date_to_asctime

    text = "#{user.nickname} retweeted a status."

    announced_user = user_by_ap_id(users, announced_activity.data["actor"])
    retweeted_status = to_map(announced_activity, Map.merge(%{user: announced_user}, opts))
    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, opts),
      "statusnet_html" => text,
      "text" => text,
      "is_local" => true,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=note",
      "created_at" => created_at,
      "retweeted_status" => retweeted_status
    }
  end

  def to_map(%Activity{data: %{"type" => "Like"}} = activity, %{user: user, liked_activity: liked_activity} = opts) do
    created_at = get_in(activity.data, ["published"])
    |> date_to_asctime

    text = "#{user.nickname} favorited a status."

    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, opts),
      "statusnet_html" => text,  # TODO: add summary
      "text" => text,
      "is_local" => true,
      "is_post_verb" => false,
      "uri" => "tag:#{activity.data["id"]}:objectType=Favourite",
      "created_at" => created_at,
      "in_reply_to_status_id" => liked_activity.id,
    }
  end

  def to_map(%Activity{data: %{"type" => "Follow"}} = activity, %{user: user} = opts) do
    created_at = get_in(activity.data, ["published"])
    |> date_to_asctime

    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, opts),
      "attentions" => [],
      "statusnet_html" => "",  # TODO: add summary
      "text" => "",
      "is_local" => true,
      "is_post_verb" => false,
      "created_at" => created_at,
      "in_reply_to_status_id" => nil,
    }
  end

  def to_map(%Activity{} = activity, %{user: user} = opts) do
    content = get_in(activity.data, ["object", "content"])
    created_at = get_in(activity.data, ["object", "published"])
    |> date_to_asctime
    like_count = get_in(activity.data, ["object", "like_count"]) || 0
    announcement_count = get_in(activity.data, ["object", "announcement_count"]) || 0
    favorited = opts[:for] && opts[:for].ap_id in (activity.data["object"]["likes"] || [])
    repeated = opts[:for] && opts[:for].ap_id in (activity.data["object"]["announcements"] || [])

    mentions = opts[:mentioned] || []

    attentions = activity.data["to"]
    |> Enum.map(fn (ap_id) -> Enum.find(mentions, fn(user) -> ap_id == user.ap_id end) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn (user) -> UserRepresenter.to_map(user, opts) end)


    conversation_id = with context when not is_nil(context) <- activity.data["context"] do
      TwitterAPI.context_to_conversation_id(context)
    else _e -> nil
    end

    %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, opts),
      "attentions" => [],
      "statusnet_html" => content,
      "text" => HtmlSanitizeEx.strip_tags(content),
      "is_local" => true,
      "is_post_verb" => true,
      "created_at" => created_at,
      "in_reply_to_status_id" => activity.data["object"]["inReplyToStatusId"],
      "statusnet_conversation_id" => conversation_id,
      "attachments" => (activity.data["object"]["attachment"] || []) |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions,
      "fave_num" => like_count,
      "repeat_num" => announcement_count,
      "favorited" => !!favorited,
      "repeated" => !!repeated,
    }
  end

  defp date_to_asctime(date) do
    with {:ok, date, _offset} <- date |> DateTime.from_iso8601 do
      Calendar.Strftime.strftime!(date, "%a %b %d %H:%M:%S %z %Y")
    else _e ->
      ""
    end
  end
end
