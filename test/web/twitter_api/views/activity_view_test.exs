# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.ActivityViewTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.UserView

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  import Mock

  test "returns a temporary ap_id based user for activities missing db users" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!", "visibility" => "direct"})

    Repo.delete(user)
    Cachex.clear(:user_cache)

    %{"user" => tw_user} = ActivityView.render("activity.json", activity: activity)

    assert tw_user["screen_name"] == "erroruser@example.com"
    assert tw_user["name"] == user.ap_id
    assert tw_user["statusnet_profile_url"] == user.ap_id
  end

  test "tries to get a user by nickname if fetching by ap_id doesn't work" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!", "visibility" => "direct"})

    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{ap_id: "#{user.ap_id}/extension/#{user.nickname}"})
      |> Repo.update()

    Cachex.clear(:user_cache)

    result = ActivityView.render("activity.json", activity: activity)
    assert result["user"]["id"] == user.id
  end

  test "tells if the message is muted for some reason" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, user} = User.mute(user, other_user)

    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "test"})
    status = ActivityView.render("activity.json", %{activity: activity})

    assert status["muted"] == false

    status = ActivityView.render("activity.json", %{activity: activity, for: user})

    assert status["muted"] == true
  end

  test "a create activity with a html status" do
    text = """
    #Bike log - Commute Tuesday\nhttps://pla.bike/posts/20181211/\n#cycling #CHScycling #commute\nMVIMG_20181211_054020.jpg
    """

    {:ok, activity} = CommonAPI.post(insert(:user), %{"status" => text})

    result = ActivityView.render("activity.json", activity: activity)

    assert result["statusnet_html"] ==
             "<a class=\"hashtag\" data-tag=\"bike\" href=\"http://localhost:4001/tag/bike\" rel=\"tag\">#Bike</a> log - Commute Tuesday<br /><a href=\"https://pla.bike/posts/20181211/\">https://pla.bike/posts/20181211/</a><br /><a class=\"hashtag\" data-tag=\"cycling\" href=\"http://localhost:4001/tag/cycling\" rel=\"tag\">#cycling</a> <a class=\"hashtag\" data-tag=\"chscycling\" href=\"http://localhost:4001/tag/chscycling\" rel=\"tag\">#CHScycling</a> <a class=\"hashtag\" data-tag=\"commute\" href=\"http://localhost:4001/tag/commute\" rel=\"tag\">#commute</a><br />MVIMG_20181211_054020.jpg"

    assert result["text"] ==
             "#Bike log - Commute Tuesday\nhttps://pla.bike/posts/20181211/\n#cycling #CHScycling #commute\nMVIMG_20181211_054020.jpg"
  end

  test "a create activity with a summary containing emoji" do
    {:ok, activity} =
      CommonAPI.post(insert(:user), %{
        "spoiler_text" => ":firefox: meow",
        "status" => "."
      })

    result = ActivityView.render("activity.json", activity: activity)

    expected = ":firefox: meow"

    expected_html =
      "<img class=\"emoji\" alt=\"firefox\" title=\"firefox\" src=\"http://localhost:4001/emoji/Firefox.gif\" /> meow"

    assert result["summary"] == expected
    assert result["summary_html"] == expected_html
  end

  test "a create activity with a summary containing invalid HTML" do
    {:ok, activity} =
      CommonAPI.post(insert(:user), %{
        "spoiler_text" => "<span style=\"color: magenta; font-size: 32px;\">meow</span>",
        "status" => "."
      })

    result = ActivityView.render("activity.json", activity: activity)

    expected = "meow"

    assert result["summary"] == expected
    assert result["summary_html"] == expected
  end

  test "a create activity with a note" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!", "visibility" => "direct"})
    object = Object.normalize(activity)

    result = ActivityView.render("activity.json", activity: activity)

    convo_id = Utils.context_to_conversation_id(object.data["context"])

    expected = %{
      "activity_type" => "post",
      "attachments" => [],
      "attentions" => [
        UserView.render("show.json", %{user: other_user})
      ],
      "created_at" => object.data["published"] |> Utils.date_to_asctime(),
      "external_url" => object.data["id"],
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
      "pinned" => false,
      "statusnet_conversation_id" => convo_id,
      "summary" => "",
      "summary_html" => "",
      "statusnet_html" =>
        "Hey <span class=\"h-card\"><a data-user=\"#{other_user.id}\" class=\"u-url mention\" href=\"#{
          other_user.ap_id
        }\">@<span>shp</span></a></span>!",
      "tags" => [],
      "text" => "Hey @shp!",
      "uri" => object.data["id"],
      "user" => UserView.render("show.json", %{user: user}),
      "visibility" => "direct",
      "card" => nil,
      "muted" => false
    }

    assert result == expected
  end

  test "a list of activities" do
    user = insert(:user)
    other_user = insert(:user, %{nickname: "shp"})
    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey @shp!"})
    object = Object.normalize(activity)

    convo_id = Utils.context_to_conversation_id(object.data["context"])

    mocks = [
      {
        Utils,
        [:passthrough],
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
      refute called(Utils.context_to_conversation_id(:_))
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
    {:ok, announce, object} = CommonAPI.repeat(activity.id, other_user)

    convo_id = Utils.context_to_conversation_id(object.data["context"])

    activity = Activity.get_by_id(activity.id)

    result = ActivityView.render("activity.json", activity: announce)

    expected = %{
      "activity_type" => "repeat",
      "created_at" => announce.data["published"] |> Utils.date_to_asctime(),
      "external_url" => announce.data["id"],
      "id" => announce.id,
      "is_local" => true,
      "is_post_verb" => false,
      "statusnet_html" => "shp repeated a status.",
      "text" => "shp repeated a status.",
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
      "uri" => Object.normalize(delete).data["id"],
      "user" => UserView.render("show.json", user: user)
    }

    assert result == expected
  end

  test "a peertube video" do
    {:ok, object} =
      Pleroma.Object.Fetcher.fetch_object_from_id(
        "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
      )

    %Activity{} = activity = Activity.get_create_by_object_ap_id(object.data["id"])

    result = ActivityView.render("activity.json", activity: activity)

    assert length(result["attachments"]) == 1
    assert result["summary"] == "Friday Night"
  end

  test "special characters are not escaped in text field for status created" do
    text = "<3 is on the way"

    {:ok, activity} = CommonAPI.post(insert(:user), %{"status" => text})

    result = ActivityView.render("activity.json", activity: activity)

    assert result["text"] == text
  end
end
