# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.ActivityViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Repo
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  import Mock

  test "a create activity with a html status" do
    text = """
    #Bike log - Commute Tuesday\nhttps://pla.bike/posts/20181211/\n#cycling #CHScycling #commute\nMVIMG_20181211_054020.jpg
    """

    {:ok, activity} = CommonAPI.post(insert(:user), %{"status" => text})

    result = ActivityView.render("activity.json", activity: activity)

    assert result["statusnet_html"] ==
             "<a data-tag=\"bike\" href=\"http://localhost:4001/tag/bike\">#Bike</a> log - Commute Tuesday<br /><a href=\"https://pla.bike/posts/20181211/\">https://pla.bike/posts/20181211/</a><br /><a data-tag=\"cycling\" href=\"http://localhost:4001/tag/cycling\">#cycling</a> <a data-tag=\"chscycling\" href=\"http://localhost:4001/tag/chscycling\">#CHScycling</a> <a data-tag=\"commute\" href=\"http://localhost:4001/tag/commute\">#commute</a><br />MVIMG_20181211_054020.jpg"

    assert result["text"] ==
             "#Bike log - Commute Tuesday\nhttps://pla.bike/posts/20181211/\n#cycling #CHScycling #commute\nMVIMG_20181211_054020.jpg"
  end

  test "a create activity with a note" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!", "visibility" => "direct"})

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
      "in_reply_to_screen_name" => nil,
      "in_reply_to_user_id" => nil,
      "in_reply_to_profileurl" => nil,
      "in_reply_to_ostatus_uri" => nil,
      "is_local" => true,
      "is_post_verb" => true,
      "possibly_sensitive" => false,
      "repeat_num" => 0,
      "repeated" => false,
      "statusnet_conversation_id" => convo_id,
      "summary" => "",
      "statusnet_html" =>
        "Hey <span><a data-user=\"#{other_user.id}\" href=\"#{other_user.ap_id}\">@<span>shp</span></a></span>!",
      "tags" => [],
      "text" => "Hey @shp!",
      "uri" => activity.data["object"]["id"],
      "user" => UserView.render("show.json", %{user: user}),
      "visibility" => "direct"
    }

    assert result == expected
  end

  test "a list of activities" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})
    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})

    convo_id = TwitterAPI.context_to_conversation_id(activity.data["object"]["context"])

    mocks = [
      {
        TwitterAPI,
        [],
        [context_to_conversation_id: fn _ -> false end]
      },
      {
        User,
        [:passthrough],
        [get_cached_by_ap_id: fn _ -> nil end]
      }
    ]

    with_mocks mocks do
      [result] = ActivityView.render("index.json", activities: [activity])

      assert result["statusnet_conversation_id"] == convo_id
      assert result["user"]
      refute called(TwitterAPI.context_to_conversation_id(:_))
      refute called(User.get_cached_by_ap_id(user.ap_id))
      refute called(User.get_cached_by_ap_id(other_user.ap_id))
    end
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
    activity = Pleroma.Activity.get_by_ap_id(activity.data["id"])

    expected = %{
      "activity_type" => "like",
      "created_at" => like.data["published"] |> Utils.date_to_asctime(),
      "external_url" => like.data["id"],
      "id" => like.id,
      "in_reply_to_status_id" => activity.id,
      "is_local" => true,
      "is_post_verb" => false,
      "favorited_status" => ActivityView.render("activity.json", activity: activity),
      "statusnet_html" => "shp favorited a status.",
      "text" => "shp favorited a status.",
      "uri" => "tag:#{like.data["id"]}:objectType=Favourite",
      "user" => UserView.render("show.json", user: other_user)
    }

    assert result == expected
  end

  test "a like activity for deleted post" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})
    {:ok, like, _object} = CommonAPI.favorite(activity.id, other_user)
    CommonAPI.delete(activity.id, user)

    result = ActivityView.render("activity.json", activity: like)

    expected = %{
      "activity_type" => "like",
      "created_at" => like.data["published"] |> Utils.date_to_asctime(),
      "external_url" => like.data["id"],
      "id" => like.id,
      "in_reply_to_status_id" => nil,
      "is_local" => true,
      "is_post_verb" => false,
      "favorited_status" => nil,
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

  test "A follow activity" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, follower} = User.follow(user, other_user)
    {:ok, follow} = ActivityPub.follow(follower, other_user)

    result = ActivityView.render("activity.json", activity: follow)

    expected = %{
      "activity_type" => "follow",
      "attentions" => [],
      "created_at" => follow.data["published"] |> Utils.date_to_asctime(),
      "external_url" => follow.data["id"],
      "id" => follow.id,
      "in_reply_to_status_id" => nil,
      "is_local" => true,
      "is_post_verb" => false,
      "statusnet_html" => "#{user.nickname} started following shp",
      "text" => "#{user.nickname} started following shp",
      "user" => UserView.render("show.json", user: user)
    }

    assert result == expected
  end

  test "a delete activity" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})
    {:ok, delete} = CommonAPI.delete(activity.id, user)

    result = ActivityView.render("activity.json", activity: delete)

    expected = %{
      "activity_type" => "delete",
      "attentions" => [],
      "created_at" => delete.data["published"] |> Utils.date_to_asctime(),
      "external_url" => delete.data["id"],
      "id" => delete.id,
      "in_reply_to_status_id" => nil,
      "is_local" => true,
      "is_post_verb" => false,
      "statusnet_html" => "deleted notice {{tag",
      "text" => "deleted notice {{tag",
      "uri" => delete.data["object"],
      "user" => UserView.render("show.json", user: user)
    }

    assert result == expected
  end

  test "a peertube video" do
    {:ok, object} =
      ActivityPub.fetch_object_from_id(
        "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
      )

    %Activity{} = activity = Activity.get_create_activity_by_object_ap_id(object.data["id"])

    result = ActivityView.render("activity.json", activity: activity)

    assert length(result["attachments"]) == 1
    assert result["summary"] == "Friday Night"
  end
end
