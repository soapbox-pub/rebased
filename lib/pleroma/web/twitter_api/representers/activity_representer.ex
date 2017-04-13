defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ObjectRepresenter}
  alias Pleroma.Activity


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

    mentions = opts[:mentioned] || []

    attentions = activity.data["to"]
    |> Enum.map(fn (ap_id) -> Enum.find(mentions, fn(user) -> ap_id == user.ap_id end) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn (user) -> UserRepresenter.to_map(user, opts) end)

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
      "statusnet_conversation_id" => activity.data["object"]["statusnetConversationId"],
      "attachments" => (activity.data["object"]["attachment"] || []) |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions,
      "fave_num" => like_count
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
