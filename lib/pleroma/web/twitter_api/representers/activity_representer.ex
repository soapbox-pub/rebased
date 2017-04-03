defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  use Pleroma.Web.TwitterAPI.Representers.BaseRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ObjectRepresenter}
  alias Pleroma.Activity

  def to_map(%Activity{} = activity, %{user: user} = opts) do
    content = get_in(activity.data, ["object", "content"])
    published = get_in(activity.data, ["object", "published"])

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
      "text" => content,
      "is_local" => true,
      "is_post_verb" => true,
      "created_at" => published,
      "in_reply_to_status_id" => activity.data["object"]["inReplyToStatusId"],
      "statusnet_conversation_id" => activity.data["object"]["statusnetConversationId"],
      "attachments" => (activity.data["object"]["attachment"] || []) |> ObjectRepresenter.enum_to_list(opts),
      "attentions" => attentions
    }
  end
end
