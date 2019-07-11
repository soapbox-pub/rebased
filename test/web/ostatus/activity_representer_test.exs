# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.ActivityRepresenterTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.ActivityRepresenter

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "an external note activity" do
    incoming = File.read!("test/fixtures/mastodon-note-cw.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    user = User.get_cached_by_ap_id(activity.data["actor"])

    tuple = ActivityRepresenter.to_simple_form(activity, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    assert String.contains?(
             res,
             ~s{<link type="text/html" href="https://mastodon.social/users/lambadalambda/updates/2314748" rel="alternate"/>}
           )
  end

  test "a note activity" do
    note_activity = insert(:note_activity)
    object_data = Object.normalize(note_activity).data

    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
    <id>#{object_data["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{object_data["content"]}</content>
    <published>#{object_data["published"]}</published>
    <updated>#{object_data["published"]}</updated>
    <ostatus:conversation ref="#{note_activity.data["context"]}">#{note_activity.data["context"]}</ostatus:conversation>
    <link ref="#{note_activity.data["context"]}" rel="ostatus:conversation" />
    <summary>#{object_data["summary"]}</summary>
    <link type="application/atom+xml" href="#{object_data["id"]}" rel="self" />
    <link type="text/html" href="#{object_data["id"]}" rel="alternate" />
    <category term="2hu"/>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
    <link name="2hu" rel="emoji" href="corndog.png" />
    """

    tuple = ActivityRepresenter.to_simple_form(note_activity, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    assert clean(res) == clean(expected)
  end

  test "a reply note" do
    user = insert(:user)
    note_object = insert(:note)
    _note = insert(:note_activity, %{note: note_object})
    object = insert(:note, %{data: %{"inReplyTo" => note_object.data["id"]}})
    answer = insert(:note_activity, %{note: object})

    Repo.update!(
      Object.change(note_object, %{data: Map.put(note_object.data, "external_url", "someurl")})
    )

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
    <id>#{object.data["id"]}</id>
    <title>New note by #{user.nickname}</title>
    <content type="html">#{object.data["content"]}</content>
    <published>#{object.data["published"]}</published>
    <updated>#{object.data["published"]}</updated>
    <ostatus:conversation ref="#{answer.data["context"]}">#{answer.data["context"]}</ostatus:conversation>
    <link ref="#{answer.data["context"]}" rel="ostatus:conversation" />
    <summary>2hu</summary>
    <link type="application/atom+xml" href="#{object.data["id"]}" rel="self" />
    <link type="text/html" href="#{object.data["id"]}" rel="alternate" />
    <category term="2hu"/>
    <thr:in-reply-to ref="#{note_object.data["id"]}" href="someurl" />
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
    <link name="2hu" rel="emoji" href="corndog.png" />
    """

    tuple = ActivityRepresenter.to_simple_form(answer, user)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    assert clean(res) == clean(expected)
  end

  test "an announce activity" do
    note = insert(:note_activity)
    user = insert(:user)
    object = Object.normalize(note)

    {:ok, announce, _object} = ActivityPub.announce(user, object)

    announce = Activity.get_by_id(announce.id)

    note_user = User.get_cached_by_ap_id(note.data["actor"])
    note = Activity.get_by_id(note.id)

    note_xml =
      ActivityRepresenter.to_simple_form(note, note_user, true)
      |> :xmerl.export_simple_content(:xmerl_xml)
      |> to_string

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/activity</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/share</activity:verb>
    <id>#{announce.data["id"]}</id>
    <title>#{user.nickname} repeated a notice</title>
    <content type="html">RT #{object.data["content"]}</content>
    <published>#{announce.data["published"]}</published>
    <updated>#{announce.data["published"]}</updated>
    <ostatus:conversation ref="#{announce.data["context"]}">#{announce.data["context"]}</ostatus:conversation>
    <link ref="#{announce.data["context"]}" rel="ostatus:conversation" />
    <link rel="self" type="application/atom+xml" href="#{announce.data["id"]}"/>
    <activity:object>
      #{note_xml}
    </activity:object>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{
      note.data["actor"]
    }"/>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
    """

    announce_xml =
      ActivityRepresenter.to_simple_form(announce, user)
      |> :xmerl.export_simple_content(:xmerl_xml)
      |> to_string

    assert clean(expected) == clean(announce_xml)
  end

  test "a like activity" do
    note = insert(:note)
    user = insert(:user)
    {:ok, like, _note} = ActivityPub.like(user, note)

    tuple = ActivityRepresenter.to_simple_form(like, user)
    refute is_nil(tuple)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    expected = """
    <activity:verb>http://activitystrea.ms/schema/1.0/favorite</activity:verb>
    <id>#{like.data["id"]}</id>
    <title>New favorite by #{user.nickname}</title>
    <content type="html">#{user.nickname} favorited something</content>
    <published>#{like.data["published"]}</published>
    <updated>#{like.data["published"]}</updated>
    <activity:object>
      <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
      <id>#{note.data["id"]}</id>
    </activity:object>
    <ostatus:conversation ref="#{like.data["context"]}">#{like.data["context"]}</ostatus:conversation>
    <link ref="#{like.data["context"]}" rel="ostatus:conversation" />
    <link rel="self" type="application/atom+xml" href="#{like.data["id"]}"/>
    <thr:in-reply-to ref="#{note.data["id"]}" />
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{
      note.data["actor"]
    }"/>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/collection" href="http://activityschema.org/collection/public"/>
    """

    assert clean(res) == clean(expected)
  end

  test "a follow activity" do
    follower = insert(:user)
    followed = insert(:user)

    {:ok, activity} =
      ActivityPub.insert(%{
        "type" => "Follow",
        "actor" => follower.ap_id,
        "object" => followed.ap_id,
        "to" => [followed.ap_id]
      })

    tuple = ActivityRepresenter.to_simple_form(activity, follower)

    refute is_nil(tuple)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/activity</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/follow</activity:verb>
    <id>#{activity.data["id"]}</id>
    <title>#{follower.nickname} started following #{activity.data["object"]}</title>
    <content type="html"> #{follower.nickname} started following #{activity.data["object"]}</content>
    <published>#{activity.data["published"]}</published>
    <updated>#{activity.data["published"]}</updated>
    <activity:object>
      <activity:object-type>http://activitystrea.ms/schema/1.0/person</activity:object-type>
      <id>#{activity.data["object"]}</id>
      <uri>#{activity.data["object"]}</uri>
    </activity:object>
    <link rel="self" type="application/atom+xml" href="#{activity.data["id"]}"/>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{
      activity.data["object"]
    }"/>
    """

    assert clean(res) == clean(expected)
  end

  test "an unfollow activity" do
    follower = insert(:user)
    followed = insert(:user)
    {:ok, _activity} = ActivityPub.follow(follower, followed)
    {:ok, activity} = ActivityPub.unfollow(follower, followed)

    tuple = ActivityRepresenter.to_simple_form(activity, follower)

    refute is_nil(tuple)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/activity</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/unfollow</activity:verb>
    <id>#{activity.data["id"]}</id>
    <title>#{follower.nickname} stopped following #{followed.ap_id}</title>
    <content type="html"> #{follower.nickname} stopped following #{followed.ap_id}</content>
    <published>#{activity.data["published"]}</published>
    <updated>#{activity.data["published"]}</updated>
    <activity:object>
      <activity:object-type>http://activitystrea.ms/schema/1.0/person</activity:object-type>
      <id>#{followed.ap_id}</id>
      <uri>#{followed.ap_id}</uri>
    </activity:object>
    <link rel="self" type="application/atom+xml" href="#{activity.data["id"]}"/>
    <link rel="mentioned" ostatus:object-type="http://activitystrea.ms/schema/1.0/person" href="#{
      followed.ap_id
    }"/>
    """

    assert clean(res) == clean(expected)
  end

  test "a delete" do
    user = insert(:user)

    activity = %Activity{
      data: %{
        "id" => "ap_id",
        "type" => "Delete",
        "actor" => user.ap_id,
        "object" => "some_id",
        "published" => "2017-06-18T12:00:18+00:00"
      }
    }

    tuple = ActivityRepresenter.to_simple_form(activity, nil)

    refute is_nil(tuple)

    res = :xmerl.export_simple_content(tuple, :xmerl_xml) |> IO.iodata_to_binary()

    expected = """
    <activity:object-type>http://activitystrea.ms/schema/1.0/activity</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/delete</activity:verb>
    <id>#{activity.data["object"]}</id>
    <title>An object was deleted</title>
    <content type="html">An object was deleted</content>
    <published>#{activity.data["published"]}</published>
    <updated>#{activity.data["published"]}</updated>
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
