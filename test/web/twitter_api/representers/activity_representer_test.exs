defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.{User, Activity, Object}
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter, ObjectRepresenter}
  alias Pleroma.Builders.UserBuilder

  test "an activity" do
    {:ok, user} = UserBuilder.insert
    {:ok, mentioned_user } = UserBuilder.insert(%{nickname: "shp", ap_id: "shp"})
    {:ok, follower} = UserBuilder.insert(%{following: [User.ap_followers(user)]})

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

    content = "Some content mentioning @shp"
    date = DateTime.utc_now() |> DateTime.to_iso8601

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
          "content" => content,
          "inReplyToStatusId" => 213123,
          "statusnetConversationId" => 4711,
          "attachment" => [
            object
          ]
        },
        "published" => date
      }
    }


    expected_status = %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user, %{for: follower}),
      "is_local" => true,
      "attentions" => [],
      "statusnet_html" => content,
      "text" => content,
      "is_post_verb" => true,
      "created_at" => date,
      "in_reply_to_status_id" => 213123,
      "statusnet_conversation_id" => 4711,
      "attachments" => [
        ObjectRepresenter.to_map(object)
      ],
      "attentions" => [
        UserRepresenter.to_map(mentioned_user, %{for: follower})
      ]
    }

    assert ActivityRepresenter.to_map(activity, %{user: user, for: follower, mentioned: [mentioned_user]}) == expected_status
  end
end
