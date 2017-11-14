defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{Repo, User, Activity, Notification}
  alias Pleroma.Web.{OStatus, CommonAPI}

  import Pleroma.Factory

  test "the home timeline", %{conn: conn} do
    user = insert(:user)
    following = insert(:user)

    {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/timelines/home")

    assert length(json_response(conn, 200)) == 0

    {:ok, user} = User.follow(user, following)

    conn = build_conn()
    |> assign(:user, user)
    |> get("/api/v1/timelines/home")

    assert [%{"content" => "test"}] = json_response(conn, 200)
  end

  test "the public timeline", %{conn: conn} do
    following = insert(:user)

    {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})
    {:ok, [_activity]} = OStatus.fetch_activity_from_url("https://shitposter.club/notice/2827873")

    conn = conn
    |> get("/api/v1/timelines/public")

    assert length(json_response(conn, 200)) == 2

    conn = build_conn()
    |> get("/api/v1/timelines/public", %{"local" => "True"})

    assert [%{"content" => "test"}] = json_response(conn, 200)
  end

  test "posting a status", %{conn: conn} do
    user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/statuses", %{"status" => "cofe", "spoiler_text" => "2hu"})

    assert %{"content" => "cofe", "id" => id, "spoiler_text" => "2hu"} = json_response(conn, 200)
    assert Repo.get(Activity, id)
  end

  test "replying to a status", %{conn: conn} do
    user = insert(:user)

    {:ok, replied_to} = TwitterAPI.create_status(user, %{"status" => "cofe"})

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

    assert %{"content" => "xD", "id" => id} = json_response(conn, 200)

    activity = Repo.get(Activity, id)

    assert activity.data["context"] == replied_to.data["context"]
    assert activity.data["object"]["inReplyToStatusId"] == replied_to.id
  end

  test "verify_credentials", %{conn: conn} do
    user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/accounts/verify_credentials")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(user.id)
  end

  test "get a status", %{conn: conn} do
    activity = insert(:note_activity)

    conn = conn
    |> get("/api/v1/statuses/#{activity.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(activity.id)
  end

  describe "deleting a status" do
    test "when you created it", %{conn: conn} do
      activity = insert(:note_activity)
      author = User.get_by_ap_id(activity.data["actor"])

      conn = conn
      |> assign(:user, author)
      |> delete("/api/v1/statuses/#{activity.id}")

      assert %{} = json_response(conn, 200)

      assert Repo.get(Activity, activity.id) == nil
    end

    test "when you didn't create it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn = conn
      |> assign(:user, user)
      |> delete("/api/v1/statuses/#{activity.id}")

      assert %{"error" => _} = json_response(conn, 403)

      assert Repo.get(Activity, activity.id) == activity
    end
  end

  describe "notifications" do
    test "list of notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)

      conn = conn
      |> assign(:user, user)
      |> get("/api/v1/notifications")

      expected_response = "hi <a href=\"#{user.ap_id}\">@#{user.nickname}</a>"
      assert [%{"status" => %{"content" => response}} | _rest] = json_response(conn, 200)
      assert response == expected_response
    end

    test "getting a single notification", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)

      conn = conn
      |> assign(:user, user)
      |> get("/api/v1/notifications/#{notification.id}")

      expected_response = "hi <a href=\"#{user.ap_id}\">@#{user.nickname}</a>"
      assert %{"status" => %{"content" => response}} = json_response(conn, 200)
      assert response == expected_response
    end

    test "dismissing a single notification", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)

      conn = conn
      |> assign(:user, user)
      |> post("/api/v1/notifications/dismiss", %{"id" => notification.id})

      assert %{} = json_response(conn, 200)
    end

    test "clearing all notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, [notification]} = Notification.create_notifications(activity)

      conn = conn
      |> assign(:user, user)
      |> post("/api/v1/notifications/clear")

      assert %{} = json_response(conn, 200)

      conn = build_conn()
      |> assign(:user, user)
      |> get("/api/v1/notifications")

      assert all = json_response(conn, 200)
      assert all == []
    end
  end

  describe "reblogging" do
    test "reblogs and returns the reblogged status", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn = conn
      |> assign(:user, user)
      |> post("/api/v1/statuses/#{activity.id}/reblog")

      assert %{"reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1}} = json_response(conn, 200)
      assert to_string(activity.id) == id
    end
  end

  describe "favoriting" do
    test "favs a status and returns it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn = conn
      |> assign(:user, user)
      |> post("/api/v1/statuses/#{activity.id}/favourite")

      assert %{"id" => id, "favourites_count" => 1, "favourited" => true} = json_response(conn, 200)
      assert to_string(activity.id) == id
    end
  end

  describe "unfavoriting" do
    test "unfavorites a status and returns it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      {:ok, _, _} = CommonAPI.favorite(activity.id, user)

      conn = conn
      |> assign(:user, user)
      |> post("/api/v1/statuses/#{activity.id}/unfavourite")

      assert %{"id" => id, "favourites_count" => 0, "favourited" => false} = json_response(conn, 200)
      assert to_string(activity.id) == id
    end
  end

  describe "user timelines" do
    test "gets a users statuses", %{conn: conn} do
      _note = insert(:note_activity)
      note_two = insert(:note_activity)

      user = User.get_by_ap_id(note_two.data["actor"])

      conn = conn
      |> get("/api/v1/accounts/#{user.id}/statuses")

      assert [%{"id" => id}] = json_response(conn, 200)

      assert id == to_string(note_two.id)
    end

    test "gets an users media", %{conn: conn} do
      note = insert(:note_activity)
      user = User.get_by_ap_id(note.data["actor"])

      file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}
      media = TwitterAPI.upload(file, "json")
      |> Poison.decode!

      {:ok, image_post} = TwitterAPI.create_status(user, %{"status" => "cofe", "media_ids" => [media["media_id"]]})

      conn = conn
      |> get("/api/v1/accounts/#{user.id}/statuses", %{"only_media" => "true"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(image_post.id)

      conn = build_conn()
      |> get("/api/v1/accounts/#{user.id}/statuses", %{"only_media" => "1"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(image_post.id)
    end
  end

  describe "user relationships" do
    test "returns the relationships for the current user", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn = conn
      |> assign(:user, user)
      |> get("/api/v1/accounts/relationships", %{"id" => [other_user.id]})

      assert [relationship] = json_response(conn, 200)

      assert to_string(other_user.id) == relationship["id"]
    end
  end

  test "account fetching", %{conn: conn} do
    user = insert(:user)

    conn = conn
    |> get("/api/v1/accounts/#{user.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(user.id)

    conn = build_conn()
    |> get("/api/v1/accounts/-1")

    assert %{"error" => "Can't find user"} = json_response(conn, 404)
  end

  test "media upload", %{conn: conn} do
    file = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}

    user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/media", %{"file" => file})

    assert media = json_response(conn, 200)

    assert media["type"] == "image"
  end

  test "hashtag timeline", %{conn: conn} do
    following = insert(:user)

    {:ok, activity} = TwitterAPI.create_status(following, %{"status" => "test #2hu"})
    {:ok, [_activity]} = OStatus.fetch_activity_from_url("https://shitposter.club/notice/2827873")

    conn = conn
    |> get("/api/v1/timelines/tag/2hu")

    assert [%{"id" => id}] = json_response(conn, 200)

    assert id == to_string(activity.id)
  end

  test "getting followers", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, user} = User.follow(user, other_user)

    conn = conn
    |> get("/api/v1/accounts/#{other_user.id}/followers")

    assert [%{"id" => id}] = json_response(conn, 200)
    assert id == to_string(user.id)
  end

  test "getting following", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, user} = User.follow(user, other_user)

    conn = conn
    |> get("/api/v1/accounts/#{user.id}/following")

    assert [%{"id" => id}] = json_response(conn, 200)
    assert id == to_string(other_user.id)
  end

  test "following / unfollowing a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/accounts/#{other_user.id}/follow")

    assert %{"id" => id, "following" => true} = json_response(conn, 200)

    user = Repo.get(User, user.id)
    conn = build_conn()
    |> assign(:user, user)
    |> post("/api/v1/accounts/#{other_user.id}/unfollow")

    assert %{"id" => id, "following" => false} = json_response(conn, 200)

    user = Repo.get(User, user.id)
    conn = build_conn()
    |> assign(:user, user)
    |> post("/api/v1/follows", %{"uri" => other_user.nickname})

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(other_user.id)
  end

  test "blocking / unblocking a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/accounts/#{other_user.id}/block")

    assert %{"id" => id, "blocking" => true} = json_response(conn, 200)

    user = Repo.get(User, user.id)
    conn = build_conn()
    |> assign(:user, user)
    |> post("/api/v1/accounts/#{other_user.id}/unblock")

    assert %{"id" => id, "blocking" => false} = json_response(conn, 200)
  end

  test "getting a list of blocks", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, user} = User.block(user, other_user)

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/blocks")

    other_user_id = to_string(other_user.id)
    assert [%{"id" => ^other_user_id}] = json_response(conn, 200)
  end

  test "unimplemented mute endpoints" do
    user = insert(:user)
    other_user = insert(:user)

    ["mute", "unmute"]
    |> Enum.each(fn(endpoint) ->
      conn = build_conn()
      |> assign(:user, user)
      |> post("/api/v1/accounts/#{other_user.id}/#{endpoint}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == to_string(other_user.id)
    end)
  end

  test "unimplemented mutes, follow_requests, blocks, domain blocks" do
    user = insert(:user)

    ["blocks", "domain_blocks", "mutes", "follow_requests"]
    |> Enum.each(fn(endpoint) ->
      conn = build_conn()
      |> assign(:user, user)
      |> get("/api/v1/#{endpoint}")

      assert [] = json_response(conn, 200)
    end)
  end

  test "account search", %{conn: conn} do
    user = insert(:user)
    user_two = insert(:user, %{nickname: "shp@shitposter.club"})
    user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/accounts/search", %{"q" => "2hu"})

    assert [account] = json_response(conn, 200)
    assert account["id"] == to_string(user_three.id)
  end

  test "search", %{conn: conn} do
    user = insert(:user)
    user_two = insert(:user, %{nickname: "shp@shitposter.club"})
    user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu"})
    {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

    conn = conn
    |> get("/api/v1/search", %{"q" => "2hu"})

    assert results = json_response(conn, 200)

    [account] = results["accounts"]
    assert account["id"] == to_string(user_three.id)

    assert results["hashtags"] == []

    [status] = results["statuses"]
    assert status["id"] == to_string(activity.id)
  end

  test "search fetches remote statuses", %{conn: conn} do
    conn = conn
    |> get("/api/v1/search", %{"q" => "https://shitposter.club/notice/2827873"})
    assert results = json_response(conn, 200)

    [status] = results["statuses"]
    assert status["uri"] == "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
  end

  test "search fetches remote accounts", %{conn: conn} do
    conn = conn
    |> get("/api/v1/search", %{"q" => "shp@social.heldscal.la", "resolve" => "true"})

    assert results = json_response(conn, 200)
    [account] = results["accounts"]
    assert account["acct"] == "shp@social.heldscal.la"
  end

  test "returns the favorites of a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _} = CommonAPI.post(other_user, %{"status" => "bla"})
    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "traps are happy"})

    {:ok, _, _} = CommonAPI.favorite(activity.id, user)

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/favourites")

    assert [status] = json_response(conn, 200)
    assert status["id"] == to_string(activity.id)
  end

  describe "updating credentials" do
    test "updates the user's bio" do
      user = insert(:user)

      conn = conn
      |> assign(:user, user)
      |> patch("/api/v1/accounts/update_credentials", %{"note" => "I drink #cofe"})

      assert user = json_response(conn, 200)
      assert user["note"] == "I drink #cofe"
    end

    test "updates the user's name" do
      user = insert(:user)

      conn = conn
      |> assign(:user, user)
      |> patch("/api/v1/accounts/update_credentials", %{"display_name" => "markorepairs"})

      assert user = json_response(conn, 200)
      assert user["display_name"] == "markorepairs"
    end

    test "updates the user's avatar" do
      user = insert(:user)

      new_avatar = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}

      conn = conn
      |> assign(:user, user)
      |> patch("/api/v1/accounts/update_credentials", %{"avatar" => new_avatar})

      assert user = json_response(conn, 200)
      assert user["avatar"] != "https://placehold.it/48x48"
    end

    test "updates the user's banner" do
      user = insert(:user)

      new_header = %Plug.Upload{content_type: "image/jpg", path: Path.absname("test/fixtures/image.jpg"), filename: "an_image.jpg"}

      conn = conn
      |> assign(:user, user)
      |> patch("/api/v1/accounts/update_credentials", %{"header" => new_header})

      assert user = json_response(conn, 200)
      assert user["header"] != "https://placehold.it/700x335"
    end
  end
end
