defmodule Pleroma.Web.OStatus.ActivityRepresenterTest do
  use Pleroma.DataCase

  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.{User, Activity, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub

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
    <id>#{note_activity.data["object"]["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{note_activity.data["object"]["content"]}</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <ostatus:conversation>#{note_activity.data["context"]}</ostatus:conversation>
    <link href="#{note_activity.data["context"]}" rel="ostatus:conversation" />
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
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
    <id>#{answer.data["object"]["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{answer.data["object"]["content"]}</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <ostatus:conversation>#{answer.data["context"]}</ostatus:conversation>
    <link href="#{answer.data["context"]}" rel="ostatus:conversation" />
    <thr:in-reply-to ref="#{note.data["object"]["id"]}" />
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
    """

    tuple = ActivityRepresenter.to_simple_form(answer, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary

    assert clean(res) == clean(expected)
  end

  test "an announce activity" do
    note = insert(:note_activity)
    user = insert(:user)
    object = Object.get_cached_by_ap_id(note.data["object"]["id"])

    {:ok, announce, object} = ActivityPub.announce(user, object)

    announce = Repo.get(Activity, announce.id)

    note_user = User.get_cached_by_ap_id(note.data["actor"])
    note = Repo.get(Activity, note.id)
    note_xml = ActivityRepresenter.to_simple_form(note, note_user)
    |> :xmerl.export_simple_content(:xmerl_xml)
    |> IO.iodata_to_binary

    updated_at = announce.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = announce.inserted_at
    |> NaiveDateTime.to_iso8601

    expected = """
    <activity:verb>http://activitystrea.ms/schema/1.0/share</activity:verb>
    <id>#{announce.data["id"]}</id>
    <title>#{user.nickname} repeated a notice</title>
    <content type="html">RT #{note.data["object"]["content"]}</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <ostatus:conversation>#{announce.data["context"]}</ostatus:conversation>
    <link href="#{announce.data["context"]}" rel="ostatus:conversation" />
    <thr:in-reply-to ref="#{note.data["object"]["id"]}" />
    <activity:object>
      #{note_xml}
    </activity:object>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{note.data["actor"]}"/>
    """

    announce_xml = ActivityRepresenter.to_simple_form(announce, user)
    |> :xmerl.export_simple_content(:xmerl_xml)
    |> IO.iodata_to_binary

    assert clean(expected) == clean(announce_xml)
  end

  test "a like activity" do
    note = insert(:note)
    user = insert(:user)
    {:ok, like, _note} = ActivityPub.like(user, note)

    updated_at = like.updated_at
    |> NaiveDateTime.to_iso8601
    inserted_at = like.inserted_at
    |> NaiveDateTime.to_iso8601

    tuple = ActivityRepresenter.to_simple_form(like, user)
    refute is_nil(tuple)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary

    expected = """
    <activity:verb>http://activitystrea.ms/schema/1.0/favorite</activity:verb>
    <id>#{like.data["id"]}</id>
    <title>New favorite by #{user.nickname}</title>
    <content type="html">#{user.nickname} favorited something</content>
    <published>#{inserted_at}</published>
    <updated>#{updated_at}</updated>
    <activity:object>
      <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
      <id>#{note.data["id"]}</id>
    </activity:object>
    <ostatus:conversation>#{like.data["context"]}</ostatus:conversation>
    <link href="#{like.data["context"]}" rel="ostatus:conversation" />
    <thr:in-reply-to ref="#{note.data["id"]}" />
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{note.data["actor"]}"/>
    """

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
