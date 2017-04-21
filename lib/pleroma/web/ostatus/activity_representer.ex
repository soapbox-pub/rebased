defmodule Pleroma.Web.OStatus.ActivityRepresenter do
  def to_simple_form(%{data: %{"object" => %{"type" => "Note"}}} = activity, user) do
    h = fn(str) -> [to_charlist(str)] end

    updated_at = activity.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = activity.inserted_at
    |> NaiveDateTime.to_iso8601

    [
      {:"activity:object-type", ['http://activitystrea.ms/schema/1.0/note']},
      {:"activity:verb", ['http://activitystrea.ms/schema/1.0/post']},
      {:id, h.(activity.data["object"]["id"])},
      {:title, ['New note by #{user.nickname}']},
      {:content, [type: 'html'], h.(activity.data["object"]["content"])},
      {:published, h.(inserted_at)},
      {:updated, h.(updated_at)}
    ]
  end
end
