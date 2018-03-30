defmodule Pleroma.Web.TwitterAPI.ActivityViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  import Pleroma.Factory

  test "a create activity with a note" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})

    result = ActivityView.render("activity.json", activity: activity)

    convo_id = TwitterAPI.context_to_conversation_id(activity.data["object"]["context"])

    expected = %{
      "activity_type" => "post",
      "attachments" => [],
      "attentions" => [
        UserView.render("show.json", %{user: other_user})
      ],
      "created_at" => activity.data["object"]["published"] |> Utils.date_to_asctime,
      "external_url" => activity.data["object"]["id"],
      "fave_num" => 0,
      "favorited" => false,
      "id" => activity.id,
      "in_reply_to_status_id" => nil,
      "is_local" => true,
      "is_post_verb" => true,
      "possibly_sensitive" => false,
      "repeat_num" => 0,
      "repeated" => false,
      "statusnet_conversation_id" => convo_id,
      "statusnet_html" =>
        "Hey <span><a href=\"http://localhost:4001/users/nick1\">@<span>shp</span></a></span>!",
      "tags" => [],
      "text" => "Hey @shp!",
      "uri" => activity.data["object"]["id"],
      "user" => UserView.render("show.json", %{user: user})
    }

    assert result == expected
  end
end
