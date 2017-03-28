defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Builders.UserBuilder

  test "an activity" do
    {:ok, user} = UserBuilder.insert
    {:ok, follower} = UserBuilder.insert(%{following: [User.ap_followers(user)]})

    content = "Some content"
    date = DateTime.utc_now() |> DateTime.to_iso8601

    activity = %Activity{
      id: 1,
      data: %{
        "type" => "Create",
        "to" => [
          User.ap_followers(user),
          "https://www.w3.org/ns/activitystreams#Public"
        ],
        "actor" => User.ap_id(user),
        "object" => %{
          "published" => date,
          "type" => "Note",
          "content" => content,
          "inReplyToStatusId" => 213123,
          "statusnetConversationId" => 4711
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
      "statusnet_conversation_id" => 4711
    }

    assert ActivityRepresenter.to_map(activity, %{user: user, for: follower}) == expected_status
  end
end
