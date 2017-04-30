defmodule Pleroma.Web.OStatus.ActivityRepresenter do
  alias Pleroma.Activity
  require Logger

  defp get_in_reply_to(%{"object" => %{ "inReplyTo" => in_reply_to}}) do
    [{:"thr:in-reply-to", [ref: to_charlist(in_reply_to)], []}]
  end

  defp get_in_reply_to(_), do: []

  def to_simple_form(%{data: %{"object" => %{"type" => "Note"}}} = activity, user) do
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
    ] ++ attachments ++ in_reply_to
  end

  def to_simple_form(_,_), do: nil
end
