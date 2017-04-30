defmodule Pleroma.Web.OStatus.ActivityRepresenterTest do
  use Pleroma.DataCase

  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.{User, Activity}

  import Pleroma.Factory

  test "a note activity" do
    note_activity = insert(:note_activity)
    updated_at = note_activity.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = note_activity.inserted_at
    |> NaiveDateTime.to_iso8601

    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
    <id>#{note_activity.data["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{note_activity.data["object"]["content"]}</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <ostatus:conversation>#{note_activity.data["context"]}</ostatus:conversation>
    <link href="#{note_activity.data["context"]}" rel="ostatus:conversation" />
    """

    tuple = ActivityRepresenter.to_simple_form(note_activity, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary

    assert clean(res) == clean(expected)
  end

  test "a reply note" do
    note = insert(:note_activity)
    answer = insert(:note_activity)
    object = answer.data["object"]
    object = Map.put(object, "inReplyTo", note.data["object"]["id"])

    data = %{answer.data | "object" => object}
    answer = %{answer | data: data}

    updated_at = answer.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = answer.inserted_at
    |> NaiveDateTime.to_iso8601

    user = User.get_cached_by_ap_id(answer.data["actor"])

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
    <id>#{answer.data["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{answer.data["object"]["content"]}</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <ostatus:conversation>#{answer.data["context"]}</ostatus:conversation>
    <link href="#{answer.data["context"]}" rel="ostatus:conversation" />
    <thr:in-reply-to ref="#{note.data["id"]}" />
    """

    tuple = ActivityRepresenter.to_simple_form(answer, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary

    assert clean(res) == clean(expected)
  end

  test "an unknown activity" do
    tuple = ActivityRepresenter.to_simple_form(%Activity{}, nil)
    assert is_nil(tuple)
  end

  defp clean(string) do
    String.replace(string, ~r/\s/, "")
  end
end
