defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Builders.UserBuilder

  test "an activity" do
    {:ok, user} = UserBuilder.insert
    content = "Some content"
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
          "type" => "Note",
          "content" => content
        }
      }
    }


    expected_status = %{
      "id" => activity.id,
      "user" => UserRepresenter.to_map(user),
      "is_local" => true,
      "attentions" => [],
      "statusnet_html" => content,
      "text" => content,
      "is_post_verb" => true
    }

    assert ActivityRepresenter.to_map(activity, %{user: user}) == expected_status
  end
end
