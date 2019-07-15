# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.TwitterAPITest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.UserView

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "create a status" do
    user = insert(:user)
    mentioned_user = insert(:user, %{nickname: "shp", ap_id: "shp"})

    object_data = %{
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

    object = Repo.insert!(%Object{data: object_data})

    input = %{
      "status" =>
        "Hello again, @shp.<script></script>\nThis is on another :firefox: line. #2hu #epic #phantasmagoric",
      "media_ids" => [object.id]
    }

    {:ok, activity = %Activity{}} = TwitterAPI.create_status(user, input)
    object = Object.normalize(activity)

    expected_text =
      "Hello again, <span class='h-card'><a data-user='#{mentioned_user.id}' class='u-url mention' href='shp'>@<span>shp</span></a></span>.&lt;script&gt;&lt;/script&gt;<br>This is on another :firefox: line. <a class='hashtag' data-tag='2hu' href='http://localhost:4001/tag/2hu' rel='tag'>#2hu</a> <a class='hashtag' data-tag='epic' href='http://localhost:4001/tag/epic' rel='tag'>#epic</a> <a class='hashtag' data-tag='phantasmagoric' href='http://localhost:4001/tag/phantasmagoric' rel='tag'>#phantasmagoric</a><br><a href=\"http://example.org/image.jpg\" class='attachment'>image.jpg</a>"

    assert get_in(object.data, ["content"]) == expected_text
    assert get_in(object.data, ["type"]) == "Note"
    assert get_in(object.data, ["actor"]) == user.ap_id
    assert get_in(activity.data, ["actor"]) == user.ap_id
    assert Enum.member?(get_in(activity.data, ["cc"]), User.ap_followers(user))

    assert Enum.member?(
             get_in(activity.data, ["to"]),
             "https://www.w3.org/ns/activitystreams#Public"
           )

    assert Enum.member?(get_in(activity.data, ["to"]), "shp")
    assert activity.local == true

    assert %{"firefox" => "http://localhost:4001/emoji/Firefox.gif"} = object.data["emoji"]

    # hashtags
    assert object.data["tag"] == ["2hu", "epic", "phantasmagoric"]

    # Add a context
    assert is_binary(get_in(activity.data, ["context"]))
    assert is_binary(get_in(object.data, ["context"]))

    assert is_list(object.data["attachment"])

    assert activity.data["object"] == object.data["id"]

    user = User.get_cached_by_ap_id(user.ap_id)

    assert user.info.note_count == 1
  end

  test "create a status that is a reply" do
    user = insert(:user)

    input = %{
      "status" => "Hello again."
    }

    {:ok, activity = %Activity{}} = TwitterAPI.create_status(user, input)
    object = Object.normalize(activity)

    input = %{
      "status" => "Here's your (you).",
      "in_reply_to_status_id" => activity.id
    }

    {:ok, reply = %Activity{}} = TwitterAPI.create_status(user, input)
    reply_object = Object.normalize(reply)

    assert get_in(reply.data, ["context"]) == get_in(activity.data, ["context"])

    assert get_in(reply_object.data, ["context"]) == get_in(object.data, ["context"])

    assert get_in(reply_object.data, ["inReplyTo"]) == get_in(activity.data, ["object"])
    assert Activity.get_in_reply_to_activity(reply).id == activity.id
  end

  test "Follow another user using user_id" do
    user = insert(:user)
    followed = insert(:user)

    {:ok, user, followed, _activity} = TwitterAPI.follow(user, %{"user_id" => followed.id})
    assert User.ap_followers(followed) in user.following

    {:ok, _, _, _} = TwitterAPI.follow(user, %{"user_id" => followed.id})
  end

  test "Follow another user using screen_name" do
    user = insert(:user)
    followed = insert(:user)

    {:ok, user, followed, _activity} =
      TwitterAPI.follow(user, %{"screen_name" => followed.nickname})

    assert User.ap_followers(followed) in user.following

    followed = User.get_cached_by_ap_id(followed.ap_id)
    assert followed.info.follower_count == 1

    {:ok, _, _, _} = TwitterAPI.follow(user, %{"screen_name" => followed.nickname})
  end

  test "Unfollow another user using user_id" do
    unfollowed = insert(:user)
    user = insert(:user, %{following: [User.ap_followers(unfollowed)]})
    ActivityPub.follow(user, unfollowed)

    {:ok, user, unfollowed} = TwitterAPI.unfollow(user, %{"user_id" => unfollowed.id})
    assert user.following == []

    {:error, msg} = TwitterAPI.unfollow(user, %{"user_id" => unfollowed.id})
    assert msg == "Not subscribed!"
  end

  test "Unfollow another user using screen_name" do
    unfollowed = insert(:user)
    user = insert(:user, %{following: [User.ap_followers(unfollowed)]})

    ActivityPub.follow(user, unfollowed)

    {:ok, user, unfollowed} = TwitterAPI.unfollow(user, %{"screen_name" => unfollowed.nickname})
    assert user.following == []

    {:error, msg} = TwitterAPI.unfollow(user, %{"screen_name" => unfollowed.nickname})
    assert msg == "Not subscribed!"
  end

  test "Block another user using user_id" do
    user = insert(:user)
    blocked = insert(:user)

    {:ok, user, blocked} = TwitterAPI.block(user, %{"user_id" => blocked.id})
    assert User.blocks?(user, blocked)
  end

  test "Block another user using screen_name" do
    user = insert(:user)
    blocked = insert(:user)

    {:ok, user, blocked} = TwitterAPI.block(user, %{"screen_name" => blocked.nickname})
    assert User.blocks?(user, blocked)
  end

  test "Unblock another user using user_id" do
    unblocked = insert(:user)
    user = insert(:user)
    {:ok, user, _unblocked} = TwitterAPI.block(user, %{"user_id" => unblocked.id})

    {:ok, user, _unblocked} = TwitterAPI.unblock(user, %{"user_id" => unblocked.id})
    assert user.info.blocks == []
  end

  test "Unblock another user using screen_name" do
    unblocked = insert(:user)
    user = insert(:user)
    {:ok, user, _unblocked} = TwitterAPI.block(user, %{"screen_name" => unblocked.nickname})

    {:ok, user, _unblocked} = TwitterAPI.unblock(user, %{"screen_name" => unblocked.nickname})
    assert user.info.blocks == []
  end

  test "upload a file" do
    user = insert(:user)

    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    response = TwitterAPI.upload(file, user)

    assert is_binary(response)
  end

  test "it favorites a status, returns the updated activity" do
    user = insert(:user)
    other_user = insert(:user)
    note_activity = insert(:note_activity)

    {:ok, status} = TwitterAPI.fav(user, note_activity.id)
    updated_activity = Activity.get_by_ap_id(note_activity.data["id"])
    assert ActivityView.render("activity.json", %{activity: updated_activity})["fave_num"] == 1

    object = Object.normalize(note_activity)

    assert object.data["like_count"] == 1

    assert status == updated_activity

    {:ok, _status} = TwitterAPI.fav(other_user, note_activity.id)

    object = Object.normalize(note_activity)

    assert object.data["like_count"] == 2

    updated_activity = Activity.get_by_ap_id(note_activity.data["id"])
    assert ActivityView.render("activity.json", %{activity: updated_activity})["fave_num"] == 2
  end

  test "it unfavorites a status, returns the updated activity" do
    user = insert(:user)
    note_activity = insert(:note_activity)
    object = Object.normalize(note_activity)

    {:ok, _like_activity, _object} = ActivityPub.like(user, object)
    updated_activity = Activity.get_by_ap_id(note_activity.data["id"])

    assert ActivityView.render("activity.json", activity: updated_activity)["fave_num"] == 1

    {:ok, activity} = TwitterAPI.unfav(user, note_activity.id)

    assert ActivityView.render("activity.json", activity: activity)["fave_num"] == 0
  end

  test "it retweets a status and returns the retweet" do
    user = insert(:user)
    note_activity = insert(:note_activity)

    {:ok, status} = TwitterAPI.repeat(user, note_activity.id)
    updated_activity = Activity.get_by_ap_id(note_activity.data["id"])

    assert status == updated_activity
  end

  test "it unretweets an already retweeted status" do
    user = insert(:user)
    note_activity = insert(:note_activity)

    {:ok, _status} = TwitterAPI.repeat(user, note_activity.id)
    {:ok, status} = TwitterAPI.unrepeat(user, note_activity.id)
    updated_activity = Activity.get_by_ap_id(note_activity.data["id"])

    assert status == updated_activity
  end

  test "it registers a new user and returns the user." do
    data = %{
      "nickname" => "lain",
      "email" => "lain@wired.jp",
      "fullname" => "lain iwakura",
      "password" => "bear",
      "confirm" => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)

    fetched_user = User.get_cached_by_nickname("lain")

    assert UserView.render("show.json", %{user: user}) ==
             UserView.render("show.json", %{user: fetched_user})
  end

  test "it registers a new user with empty string in bio and returns the user." do
    data = %{
      "nickname" => "lain",
      "email" => "lain@wired.jp",
      "fullname" => "lain iwakura",
      "bio" => "",
      "password" => "bear",
      "confirm" => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)

    fetched_user = User.get_cached_by_nickname("lain")

    assert UserView.render("show.json", %{user: user}) ==
             UserView.render("show.json", %{user: fetched_user})
  end

  test "it sends confirmation email if :account_activation_required is specified in instance config" do
    setting = Pleroma.Config.get([:instance, :account_activation_required])

    unless setting do
      Pleroma.Config.put([:instance, :account_activation_required], true)
      on_exit(fn -> Pleroma.Config.put([:instance, :account_activation_required], setting) end)
    end

    data = %{
      "nickname" => "lain",
      "email" => "lain@wired.jp",
      "fullname" => "lain iwakura",
      "bio" => "",
      "password" => "bear",
      "confirm" => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)

    assert user.info.confirmation_pending

    email = Pleroma.Emails.UserEmail.account_confirmation_email(user)

    notify_email = Pleroma.Config.get([:instance, :notify_email])
    instance_name = Pleroma.Config.get([:instance, :name])

    Swoosh.TestAssertions.assert_email_sent(
      from: {instance_name, notify_email},
      to: {user.name, user.email},
      html_body: email.html_body
    )
  end

  test "it registers a new user and parses mentions in the bio" do
    data1 = %{
      "nickname" => "john",
      "email" => "john@gmail.com",
      "fullname" => "John Doe",
      "bio" => "test",
      "password" => "bear",
      "confirm" => "bear"
    }

    {:ok, user1} = TwitterAPI.register_user(data1)

    data2 = %{
      "nickname" => "lain",
      "email" => "lain@wired.jp",
      "fullname" => "lain iwakura",
      "bio" => "@john test",
      "password" => "bear",
      "confirm" => "bear"
    }

    {:ok, user2} = TwitterAPI.register_user(data2)

    expected_text =
      "<span class='h-card'><a data-user='#{user1.id}' class='u-url mention' href='#{user1.ap_id}'>@<span>john</span></a></span> test"

    assert user2.bio == expected_text
  end

  describe "register with one time token" do
    setup do
      setting = Pleroma.Config.get([:instance, :registrations_open])

      if setting do
        Pleroma.Config.put([:instance, :registrations_open], false)
        on_exit(fn -> Pleroma.Config.put([:instance, :registrations_open], setting) end)
      end

      :ok
    end

    test "returns user on success" do
      {:ok, invite} = UserInviteToken.create_invite()

      data = %{
        "nickname" => "vinny",
        "email" => "pasta@pizza.vs",
        "fullname" => "Vinny Vinesauce",
        "bio" => "streamer",
        "password" => "hiptofbees",
        "confirm" => "hiptofbees",
        "token" => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)

      fetched_user = User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)

      assert invite.used == true

      assert UserView.render("show.json", %{user: user}) ==
               UserView.render("show.json", %{user: fetched_user})
    end

    test "returns error on invalid token" do
      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => "DudeLetMeInImAFairy"
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Invalid token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on expired token" do
      {:ok, invite} = UserInviteToken.create_invite()
      UserInviteToken.update_invite!(invite, used: true)

      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  describe "registers with date limited token" do
    setup do
      setting = Pleroma.Config.get([:instance, :registrations_open])

      if setting do
        Pleroma.Config.put([:instance, :registrations_open], false)
        on_exit(fn -> Pleroma.Config.put([:instance, :registrations_open], setting) end)
      end

      data = %{
        "nickname" => "vinny",
        "email" => "pasta@pizza.vs",
        "fullname" => "Vinny Vinesauce",
        "bio" => "streamer",
        "password" => "hiptofbees",
        "confirm" => "hiptofbees"
      }

      check_fn = fn invite ->
        data = Map.put(data, "token", invite.token)
        {:ok, user} = TwitterAPI.register_user(data)
        fetched_user = User.get_cached_by_nickname("vinny")

        assert UserView.render("show.json", %{user: user}) ==
                 UserView.render("show.json", %{user: fetched_user})
      end

      {:ok, data: data, check_fn: check_fn}
    end

    test "returns user on success", %{check_fn: check_fn} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today()})

      check_fn.(invite)

      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end

    test "returns user on token which expired tomorrow", %{check_fn: check_fn} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), 1)})

      check_fn.(invite)

      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end

    test "returns an error on overdue date", %{data: data} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1)})

      data = Map.put(data, "token", invite.token)

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end
  end

  describe "registers with reusable token" do
    setup do
      setting = Pleroma.Config.get([:instance, :registrations_open])

      if setting do
        Pleroma.Config.put([:instance, :registrations_open], false)
        on_exit(fn -> Pleroma.Config.put([:instance, :registrations_open], setting) end)
      end

      :ok
    end

    test "returns user on success, after him registration fails" do
      {:ok, invite} = UserInviteToken.create_invite(%{max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 99)

      data = %{
        "nickname" => "vinny",
        "email" => "pasta@pizza.vs",
        "fullname" => "Vinny Vinesauce",
        "bio" => "streamer",
        "password" => "hiptofbees",
        "confirm" => "hiptofbees",
        "token" => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      fetched_user = User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)

      assert invite.used == true

      assert UserView.render("show.json", %{user: user}) ==
               UserView.render("show.json", %{user: fetched_user})

      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  describe "registers with reusable date limited token" do
    setup do
      setting = Pleroma.Config.get([:instance, :registrations_open])

      if setting do
        Pleroma.Config.put([:instance, :registrations_open], false)
        on_exit(fn -> Pleroma.Config.put([:instance, :registrations_open], setting) end)
      end

      :ok
    end

    test "returns user on success" do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today(), max_use: 100})

      data = %{
        "nickname" => "vinny",
        "email" => "pasta@pizza.vs",
        "fullname" => "Vinny Vinesauce",
        "bio" => "streamer",
        "password" => "hiptofbees",
        "confirm" => "hiptofbees",
        "token" => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      fetched_user = User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used

      assert UserView.render("show.json", %{user: user}) ==
               UserView.render("show.json", %{user: fetched_user})
    end

    test "error after max uses" do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today(), max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 99)

      data = %{
        "nickname" => "vinny",
        "email" => "pasta@pizza.vs",
        "fullname" => "Vinny Vinesauce",
        "bio" => "streamer",
        "password" => "hiptofbees",
        "confirm" => "hiptofbees",
        "token" => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      fetched_user = User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)
      assert invite.used == true

      assert UserView.render("show.json", %{user: user}) ==
               UserView.render("show.json", %{user: fetched_user})

      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on overdue date" do
      {:ok, invite} =
        UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1), max_use: 100})

      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on with overdue date and after max" do
      {:ok, invite} =
        UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1), max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 100)

      data = %{
        "nickname" => "GrimReaper",
        "email" => "death@reapers.afterlife",
        "fullname" => "Reaper Grim",
        "bio" => "Your time has come",
        "password" => "scythe",
        "confirm" => "scythe",
        "token" => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  test "it returns the error on registration problems" do
    data = %{
      "nickname" => "lain",
      "email" => "lain@wired.jp",
      "fullname" => "lain iwakura",
      "bio" => "close the world.",
      "password" => "bear"
    }

    {:error, error_object} = TwitterAPI.register_user(data)

    assert is_binary(error_object[:error])
    refute User.get_cached_by_nickname("lain")
  end

  test "it assigns an integer conversation_id" do
    note_activity = insert(:note_activity)
    status = ActivityView.render("activity.json", activity: note_activity)

    assert is_number(status["statusnet_conversation_id"])
  end

  setup do
    Supervisor.terminate_child(Pleroma.Supervisor, Cachex)
    Supervisor.restart_child(Pleroma.Supervisor, Cachex)
    :ok
  end

  describe "fetching a user by uri" do
    test "fetches a user by uri" do
      id = "https://mastodon.social/users/lambadalambda"
      user = insert(:user)
      {:ok, represented} = TwitterAPI.get_external_profile(user, id)
      remote = User.get_cached_by_ap_id(id)

      assert represented["id"] == UserView.render("show.json", %{user: remote, for: user})["id"]

      # Also fetches the feed.
      # assert Activity.get_create_by_object_ap_id("tag:mastodon.social,2017-04-05:objectId=1641750:objectType=Status")
      # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength
    end
  end
end
