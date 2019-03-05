# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter
  alias Pleroma.Web.TwitterAPI.Representers.ObjectRepresenter
  alias Pleroma.Web.TwitterAPI.UserView
  import Pleroma.Factory

  test "a like activity" do
    user = insert(:user)
    note_activity = insert(:note_activity)
    object = Object.get_by_ap_id(note_activity.data["object"]["id"])

    {:ok, like_activity, _object} = ActivityPub.like(user, object)

    status =
      ActivityRepresenter.to_map(like_activity, %{user: user, liked_activity: note_activity})

    assert status["id"] == like_activity.id
    assert status["in_reply_to_status_id"] == note_activity.id

    note_activity = Activity.get_by_ap_id(note_activity.data["id"])
    activity_actor = Repo.get_by(User, ap_id: note_activity.data["actor"])
    liked_status = ActivityRepresenter.to_map(note_activity, %{user: activity_actor, for: user})
    assert liked_status["favorited"] == true
    assert status["activity_type"] == "like"
  end

  test "an activity" do
    user = insert(:user)
    #   {:ok, mentioned_user } = UserBuilder.insert(%{nickname: "shp", ap_id: "shp"})
    mentioned_user = insert(:user, %{nickname: "shp"})

    # {:ok, follower} = UserBuilder.insert(%{following: [User.ap_followers(user)]})
    follower = insert(:user, %{following: [User.ap_followers(user)]})

    object = %Object{
      data: %{
        "type" => "Image",
        "url" => [
          %{
            "type" => "Link",
            "mediaType" => "image/jpg",
            "href" => "http://example.org/image.jpg"
          }
        ],
        "uuid" => 1
      }
    }

    content_html =
      "<script>alert('YAY')</script>Some :2hu: content mentioning <a href='#{mentioned_user.ap_id}'>@shp</shp>"

    content = HtmlSanitizeEx.strip_tags(content_html)
    date = DateTime.from_naive!(~N[2016-05-24 13:26:08.003], "Etc/UTC") |> DateTime.to_iso8601()

    {:ok, convo_object} = Object.context_mapping("2hu") |> Repo.insert()

    to = [
      User.ap_followers(user),
      "https://www.w3.org/ns/activitystreams#Public",
      mentioned_user.ap_id
    ]

    activity = %Activity{
      id: 1,
      data: %{
        "type" => "Create",
        "id" => "id",
        "to" => to,
        "actor" => User.ap_id(user),
        "object" => %{
          "published" => date,
          "type" => "Note",
          "content" => content_html,
          "summary" => "2hu :2hu:",
          "inReplyToStatusId" => 213_123,
          "attachment" => [
            object
          ],
          "external_url" => "some url",
          "like_count" => 5,
          "announcement_count" => 3,
          "context" => "2hu",
          "tag" => ["content", "mentioning", "nsfw"],
          "emoji" => %{
            "2hu" => "corndog.png"
          }
        },
        "published" => date,
        "context" => "2hu"
      },
      local: false,
      recipients: to
    }

    corndog_emojo = ~s(<img height="32px" width="32px" alt="2hu" title="2hu" src="corndog.png" />)

    expected_html =
      ~s(<p>2hu ) <>
        corndog_emojo <>
        ~s(</p>alert\('YAY'\)Some ) <>
        corndog_emojo <>
        ~s( content mentioning <a href=") <> mentioned_user.ap_id <> ~s(">@shp</a>)

    expected_status = %{
      "id" => activity.id,
      "user" => UserView.render("show.json", %{user: user, for: follower}),
      "is_local" => false,
      "statusnet_html" => expected_html,
      "text" => "2hu :2hu:" <> content,
      "is_post_verb" => true,
      "created_at" => "Tue May 24 13:26:08 +0000 2016",
      "in_reply_to_status_id" => 213_123,
      "in_reply_to_screen_name" => nil,
      "in_reply_to_user_id" => nil,
      "in_reply_to_profileurl" => nil,
      "in_reply_to_ostatus_uri" => nil,
      "statusnet_conversation_id" => convo_object.id,
      "attachments" => [
        ObjectRepresenter.to_map(object)
      ],
      "attentions" => [
        UserView.render("show.json", %{user: mentioned_user, for: follower})
      ],
      "fave_num" => 5,
      "repeat_num" => 3,
      "favorited" => false,
      "repeated" => false,
      "pinned" => false,
      "external_url" => "some url",
      "tags" => ["nsfw", "content", "mentioning"],
      "activity_type" => "post",
      "possibly_sensitive" => true,
      "uri" => activity.data["object"]["id"],
      "visibility" => "direct",
      "card" => nil,
      "muted" => false,
      "summary" => "2hu :2hu:",
      "summary_html" =>
        "2hu <img height=\"32px\" width=\"32px\" alt=\"2hu\" title=\"2hu\" src=\"corndog.png\" />"
    }

    assert ActivityRepresenter.to_map(activity, %{
             user: user,
             for: follower,
             mentioned: [mentioned_user]
           }) == expected_status
  end

  test "a delete activity" do
    object = insert(:note)
    user = User.get_by_ap_id(object.data["actor"])

    {:ok, delete} = ActivityPub.delete(object)

    map = ActivityRepresenter.to_map(delete, %{user: user})

    assert map["is_post_verb"] == false
    assert map["activity_type"] == "delete"
    assert map["uri"] == object.data["id"]
  end
end
