defmodule Pleroma.Web.TwitterAPI.ActivityViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Repo
  alias Pleroma.Activity
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
      "created_at" => activity.data["object"]["published"] |> Utils.date_to_asctime(),
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
        "Hey <span><a href=\"#{other_user.ap_id}\">@<span>shp</span></a></span>!",
      "tags" => [],
      "text" => "Hey @shp!",
      "uri" => activity.data["object"]["id"],
      "user" => UserView.render("show.json", %{user: user})
    }

    assert result == expected
  end

  test "an activity that is a reply" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})

    {:ok, answer} =
      CommonAPI.post(other_user, %{"status" => "Hi!", "in_reply_to_status_id" => activity.id})

    result = ActivityView.render("activity.json", %{activity: answer})

    assert result["in_reply_to_status_id"] == activity.id
  end

  test "a like activity" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})
    {:ok, like, _object} = CommonAPI.favorite(activity.id, other_user)

    result = ActivityView.render("activity.json", activity: like)

    expected = %{
      "activity_type" => "like",
      "created_at" => like.data["published"] |> Utils.date_to_asctime(),
      "external_url" => like.data["id"],
      "id" => like.id,
      "in_reply_to_status_id" => activity.id,
      "is_local" => true,
      "is_post_verb" => false,
      "statusnet_html" => "shp favorited a status.",
      "text" => "shp favorited a status.",
      "uri" => "tag:#{like.data["id"]}:objectType=Favourite",
      "user" => UserView.render("show.json", user: other_user)
    }

    assert result == expected
  end

  test "an announce activity" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})
    {:ok, announce, _object} = CommonAPI.repeat(activity.id, other_user)

    convo_id = TwitterAPI.context_to_conversation_id(activity.data["object"]["context"])

    activity = Repo.get(Activity, activity.id)

    result = ActivityView.render("activity.json", activity: announce)

    expected = %{
      "activity_type" => "repeat",
      "created_at" => announce.data["published"] |> Utils.date_to_asctime(),
      "external_url" => announce.data["id"],
      "id" => announce.id,
      "is_local" => true,
      "is_post_verb" => false,
      "statusnet_html" => "shp retweeted a status.",
      "text" => "shp retweeted a status.",
      "uri" => "tag:#{announce.data["id"]}:objectType=note",
      "user" => UserView.render("show.json", user: other_user),
      "retweeted_status" => ActivityView.render("activity.json", activity: activity),
      "statusnet_conversation_id" => convo_id
    }

    assert result == expected
  end
end
