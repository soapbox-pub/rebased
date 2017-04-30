defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.{User, Activity, Object}
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter, ObjectRepresenter}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Builders.UserBuilder
  import Pleroma.Factory

  test "an announce activity" do
    user = insert(:user)
    note_activity = insert(:note_activity)
    activity_actor = Repo.get_by(User, ap_id: note_activity.data["actor"])
    object = Object.get_by_ap_id(note_activity.data["object"]["id"])

    {:ok, announce_activity, _object} = ActivityPub.announce(user, object)
    note_activity = Activity.get_by_ap_id(note_activity.data["id"])

    status = ActivityRepresenter.to_map(announce_activity, %{users: [user, activity_actor], announced_activity: note_activity, for: user})

    assert status["id"] == announce_activity.id
    assert status["user"] == UserRepresenter.to_map(user, %{for: user})

    retweeted_status = ActivityRepresenter.to_map(note_activity, %{user: activity_actor, for: user})
    assert retweeted_status["repeated"] == true

    assert status["retweeted_status"] == retweeted_status
  end

  test "a like activity" do
    user = insert(:user)
    note_activity = insert(:note_activity)
    object = Object.get_by_ap_id(note_activity.data["object"]["id"])

    {:ok, like_activity, _object} = ActivityPub.like(user, object)
    status = ActivityRepresenter.to_map(like_activity, %{user: user, liked_activity: note_activity})

    assert status["id"] == like_activity.id
    assert status["in_reply_to_status_id"] == note_activity.id

    note_activity = Activity.get_by_ap_id(note_activity.data["id"])
    activity_actor = Repo.get_by(User, ap_id: note_activity.data["actor"])
    liked_status = ActivityRepresenter.to_map(note_activity, %{user: activity_actor, for: user})
    assert liked_status["favorited"] == true
  end

  test "an activity" do
    {:ok, user} = UserBuilder.insert
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

    content_html = "Some content mentioning <a href='#{mentioned_user.ap_id}'>@shp</shp>"
    content = HtmlSanitizeEx.strip_tags(content_html)
    date = DateTime.from_naive!(~N[2016-05-24 13:26:08.003], "Etc/UTC") |> DateTime.to_iso8601

    {:ok, convo_object} = Object.context_mapping("2hu") |> Repo.insert

    activity = %Activity{
      id: 1,
      data: %{
        "type" => "Create",
        "to" => [
          User.ap_followers(user),
          "https://www.w3.org/ns/activitystreams#Public",
          mentioned_user.ap_id
        ],
        "actor" => User.ap_id(user),
        "object" => %{
          "published" => date,
          "type" => "Note",
          "content" => content_html,
          "inReplyToStatusId" => 213123,
          "attachment" => [
            object
          ],
          "like_count" => 5,
          "announcement_count" => 3,
          "context" => "2hu"
        },
        "published" => date,
        "context" => "2hu"
      }
    }


    expected_status = %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, %{for: follower}),
      "is_local" => true,
      "attentions" => [],
      "statusnet_html" => content_html,
      "text" => content,
      "is_post_verb" => true,
      "created_at" => "Tue May 24 13:26:08 +0000 2016",
      "in_reply_to_status_id" => 213123,
      "statusnet_conversation_id" => convo_object.id,
      "attachments" => [
        ObjectRepresenter.to_map(object)
      ],
      "attentions" => [
        UserRepresenter.to_map(mentioned_user, %{for: follower})
      ],
      "fave_num" => 5,
      "repeat_num" => 3,
      "favorited" => false,
      "repeated" => false
    }

    assert ActivityRepresenter.to_map(activity, %{user: user, for: follower, mentioned: [mentioned_user]}) == expected_status
  end
end
