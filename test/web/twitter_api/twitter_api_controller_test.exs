defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter
  alias Pleroma.Builders.{ActivityBuilder, UserBuilder}
  alias Pleroma.{Repo, Activity, User, Object, Notification}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.TwitterAPI.NotificationView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Comeonin.Pbkdf2

  import Pleroma.Factory

  describe "POST /api/account/update_profile_banner" do
    test "it updates the banner", %{conn: conn} do
      user = insert(:user)

      new_banner =
        "data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7"

      response =
        conn
        |> assign(:user, user)
        |> post(authenticated_twitter_api__path(conn, :update_banner), %{"banner" => new_banner})
        |> json_response(200)
    end
  end

  describe "POST /api/qvitter/update_background_image" do
    test "it updates the background", %{conn: conn} do
      user = insert(:user)

      new_bg =
        "data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7"

      response =
        conn
        |> assign(:user, user)
        |> post(authenticated_twitter_api__path(conn, :update_background), %{"img" => new_bg})
        |> json_response(200)
    end
  end

  describe "POST /api/account/verify_credentials" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/account/verify_credentials.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      conn =
        conn
        |> with_credentials(user.nickname, "test")
        |> post("/api/account/verify_credentials.json")

      assert response = json_response(conn, 200)
      assert response == UserView.render("show.json", %{user: user, token: response["token"]})
    end
  end

  describe "POST /statuses/update.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/statuses/update.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      conn_with_creds = conn |> with_credentials(user.nickname, "test")
      request_path = "/api/statuses/update.json"

      error_response = %{
        "request" => request_path,
        "error" => "Client must provide a 'status' parameter with a value."
      }

      conn = conn_with_creds |> post(request_path)
      assert json_response(conn, 400) == error_response

      conn = conn_with_creds |> post(request_path, %{status: ""})
      assert json_response(conn, 400) == error_response

      conn = conn_with_creds |> post(request_path, %{status: " "})
      assert json_response(conn, 400) == error_response

      # we post with visibility private in order to avoid triggering relay
      conn = conn_with_creds |> post(request_path, %{status: "Nice meme.", visibility: "private"})

      assert json_response(conn, 200) ==
               ActivityRepresenter.to_map(Repo.one(Activity), %{user: user})
    end
  end

  describe "GET /statuses/public_timeline.json" do
    test "returns statuses", %{conn: conn} do
      user = insert(:user)
      activities = ActivityBuilder.insert_list(30, %{}, %{user: user})
      ActivityBuilder.insert_list(10, %{}, %{user: user})
      since_id = List.last(activities).id

      conn =
        conn
        |> get("/api/statuses/public_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10
    end

    test "returns 403 to unauthenticated request when the instance is not public" do
      instance =
        Application.get_env(:pleroma, :instance)
        |> Keyword.put(:public, false)

      Application.put_env(:pleroma, :instance, instance)

      conn
      |> get("/api/statuses/public_timeline.json")
      |> json_response(403)

      instance =
        Application.get_env(:pleroma, :instance)
        |> Keyword.put(:public, true)

      Application.put_env(:pleroma, :instance, instance)
    end

    test "returns 200 to unauthenticated request when the instance is public" do
      conn
      |> get("/api/statuses/public_timeline.json")
      |> json_response(200)
    end
  end

  describe "GET /statuses/public_and_external_timeline.json" do
    test "returns 403 to unauthenticated request when the instance is not public" do
      instance =
        Application.get_env(:pleroma, :instance)
        |> Keyword.put(:public, false)

      Application.put_env(:pleroma, :instance, instance)

      conn
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(403)

      instance =
        Application.get_env(:pleroma, :instance)
        |> Keyword.put(:public, true)

      Application.put_env(:pleroma, :instance, instance)
    end

    test "returns 200 to unauthenticated request when the instance is public" do
      conn
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(200)
    end
  end

  describe "GET /statuses/show/:id.json" do
    test "returns one status", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey!"})
      actor = Repo.get_by!(User, ap_id: activity.data["actor"])

      conn =
        conn
        |> get("/api/statuses/show/#{activity.id}.json")

      response = json_response(conn, 200)

      assert response == ActivityRepresenter.to_map(activity, %{user: actor})
    end
  end

  describe "GET /users/show.json" do
    test "gets user with screen_name", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> get("/api/users/show.json", %{"screen_name" => user.nickname})

      response = json_response(conn, 200)

      assert response["id"] == user.id
    end

    test "gets user with user_id", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> get("/api/users/show.json", %{"user_id" => user.id})

      response = json_response(conn, 200)

      assert response["id"] == user.id
    end

    test "gets a user for a logged in user", %{conn: conn} do
      user = insert(:user)
      logged_in = insert(:user)

      {:ok, logged_in, user, _activity} = TwitterAPI.follow(logged_in, %{"user_id" => user.id})

      conn =
        conn
        |> with_credentials(logged_in.nickname, "test")
        |> get("/api/users/show.json", %{"user_id" => user.id})

      response = json_response(conn, 200)

      assert response["following"] == true
    end
  end

  describe "GET /statusnet/conversation/:id.json" do
    test "returns the statuses in the conversation", %{conn: conn} do
      {:ok, _user} = UserBuilder.insert()
      {:ok, activity} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, _activity_two} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"type" => "Create", "context" => "3hu"})

      conn =
        conn
        |> get("/api/statusnet/conversation/#{activity.data["context_id"]}.json")

      response = json_response(conn, 200)

      assert length(response) == 2
    end
  end

  describe "GET /statuses/friends_timeline.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = get(conn, "/api/statuses/friends_timeline.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      user = insert(:user)

      activities =
        ActivityBuilder.insert_list(30, %{"to" => [User.ap_followers(user)]}, %{user: user})

      returned_activities =
        ActivityBuilder.insert_list(10, %{"to" => [User.ap_followers(user)]}, %{user: user})

      other_user = insert(:user)
      ActivityBuilder.insert_list(10, %{}, %{user: other_user})
      since_id = List.last(activities).id

      current_user =
        Ecto.Changeset.change(current_user, following: [User.ap_followers(user)])
        |> Repo.update!()

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/friends_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10

      assert response ==
               Enum.map(returned_activities, fn activity ->
                 ActivityRepresenter.to_map(activity, %{
                   user: User.get_cached_by_ap_id(activity.data["actor"]),
                   for: current_user
                 })
               end)
    end
  end

  describe "GET /statuses/dm_timeline.json" do
    test "it show direct messages", %{conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      {:ok, user_two} = User.follow(user_two, user_one)

      {:ok, direct} =
        CommonAPI.post(user_one, %{
          "status" => "Hi @#{user_two.nickname}!",
          "visibility" => "direct"
        })

      {:ok, direct_two} =
        CommonAPI.post(user_two, %{
          "status" => "Hi @#{user_one.nickname}!",
          "visibility" => "direct"
        })

      {:ok, _follower_only} =
        CommonAPI.post(user_one, %{
          "status" => "Hi @#{user_two.nickname}!",
          "visibility" => "private"
        })

      # Only direct should be visible here
      res_conn =
        conn
        |> assign(:user, user_two)
        |> get("/api/statuses/dm_timeline.json")

      [status, status_two] = json_response(res_conn, 200)
      assert status["id"] == direct_two.id
      assert status_two["id"] == direct.id
    end
  end

  describe "GET /statuses/mentions.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = get(conn, "/api/statuses/mentions.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, activity} =
        ActivityBuilder.insert(%{"to" => [current_user.ap_id]}, %{user: current_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/mentions.json")

      response = json_response(conn, 200)

      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityRepresenter.to_map(activity, %{
                 user: current_user,
                 mentioned: [current_user]
               })
    end
  end

  describe "GET /api/qvitter/statuses/notifications.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = get(conn, "/api/qvitter/statuses/notifications.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      other_user = insert(:user)

      {:ok, _activity} =
        ActivityBuilder.insert(%{"to" => [current_user.ap_id]}, %{user: other_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/statuses/notifications.json")

      response = json_response(conn, 200)

      assert length(response) == 1

      assert response ==
               NotificationView.render("notification.json", %{
                 notifications: Notification.for_user(current_user),
                 for: current_user
               })
    end
  end

  describe "POST /api/qvitter/statuses/notifications/read" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/qvitter/statuses/notifications/read", %{"latest_id" => 1_234_567})
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials, without any params", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/qvitter/statuses/notifications/read")

      assert json_response(conn, 400) == %{
               "error" => "You need to specify latest_id",
               "request" => "/api/qvitter/statuses/notifications/read"
             }
    end

    test "with credentials, with params", %{conn: conn, user: current_user} do
      other_user = insert(:user)

      {:ok, _activity} =
        ActivityBuilder.insert(%{"to" => [current_user.ap_id]}, %{user: other_user})

      response_conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/statuses/notifications.json")

      [notification] = response = json_response(response_conn, 200)

      assert length(response) == 1

      assert notification["is_seen"] == 0

      response_conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/qvitter/statuses/notifications/read", %{"latest_id" => notification["id"]})

      [notification] = response = json_response(response_conn, 200)

      assert length(response) == 1

      assert notification["is_seen"] == 1
    end
  end

  describe "GET /statuses/user_timeline.json" do
    setup [:valid_user]

    test "without any params", %{conn: conn} do
      conn = get(conn, "/api/statuses/user_timeline.json")

      assert json_response(conn, 400) == %{
               "error" => "You need to specify screen_name or user_id",
               "request" => "/api/statuses/user_timeline.json"
             }
    end

    test "with user_id", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: user})

      conn = get(conn, "/api/statuses/user_timeline.json", %{"user_id" => user.id})
      response = json_response(conn, 200)
      assert length(response) == 1
      assert Enum.at(response, 0) == ActivityRepresenter.to_map(activity, %{user: user})
    end

    test "with screen_name", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: user})

      conn = get(conn, "/api/statuses/user_timeline.json", %{"screen_name" => user.nickname})
      response = json_response(conn, 200)
      assert length(response) == 1
      assert Enum.at(response, 0) == ActivityRepresenter.to_map(activity, %{user: user})
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: current_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/user_timeline.json")

      response = json_response(conn, 200)

      assert length(response) == 1
      assert Enum.at(response, 0) == ActivityRepresenter.to_map(activity, %{user: current_user})
    end

    test "with credentials with user_id", %{conn: conn, user: current_user} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/user_timeline.json", %{"user_id" => user.id})

      response = json_response(conn, 200)

      assert length(response) == 1
      assert Enum.at(response, 0) == ActivityRepresenter.to_map(activity, %{user: user})
    end

    test "with credentials screen_name", %{conn: conn, user: current_user} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/user_timeline.json", %{"screen_name" => user.nickname})

      response = json_response(conn, 200)

      assert length(response) == 1
      assert Enum.at(response, 0) == ActivityRepresenter.to_map(activity, %{user: user})
    end
  end

  describe "POST /friendships/create.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/friendships/create.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      followed = insert(:user)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/friendships/create.json", %{user_id: followed.id})

      current_user = Repo.get(User, current_user.id)
      assert User.ap_followers(followed) in current_user.following

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: followed, for: current_user})
    end
  end

  describe "POST /friendships/destroy.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/friendships/destroy.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      followed = insert(:user)

      {:ok, current_user} = User.follow(current_user, followed)
      assert User.ap_followers(followed) in current_user.following
      ActivityPub.follow(current_user, followed)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/friendships/destroy.json", %{user_id: followed.id})

      current_user = Repo.get(User, current_user.id)
      assert current_user.following == [current_user.ap_id]

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: followed, for: current_user})
    end
  end

  describe "POST /blocks/create.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/blocks/create.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      blocked = insert(:user)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/blocks/create.json", %{user_id: blocked.id})

      current_user = Repo.get(User, current_user.id)
      assert User.blocks?(current_user, blocked)

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: blocked, for: current_user})
    end
  end

  describe "POST /blocks/destroy.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/blocks/destroy.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      blocked = insert(:user)

      {:ok, current_user, blocked} = TwitterAPI.block(current_user, %{"user_id" => blocked.id})
      assert User.blocks?(current_user, blocked)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/blocks/destroy.json", %{user_id: blocked.id})

      current_user = Repo.get(User, current_user.id)
      assert current_user.info.blocks == []

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: blocked, for: current_user})
    end
  end

  describe "GET /help/test.json" do
    test "returns \"ok\"", %{conn: conn} do
      conn = get(conn, "/api/help/test.json")
      assert json_response(conn, 200) == "ok"
    end
  end

  describe "POST /api/qvitter/update_avatar.json" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/qvitter/update_avatar.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      avatar_image = File.read!("test/fixtures/avatar_data_uri")

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/qvitter/update_avatar.json", %{img: avatar_image})

      current_user = Repo.get(User, current_user.id)
      assert is_map(current_user.avatar)

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: current_user, for: current_user})
    end
  end

  describe "GET /api/qvitter/mutes.json" do
    setup [:valid_user]

    test "unimplemented mutes without valid credentials", %{conn: conn} do
      conn = get(conn, "/api/qvitter/mutes.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "unimplemented mutes with credentials", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/mutes.json")

      current_user = Repo.get(User, current_user.id)

      assert [] = json_response(conn, 200)
    end
  end

  describe "POST /api/favorites/create/:id" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/favorites/create/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/favorites/create/#{note_activity.id}.json")

      assert json_response(conn, 200)
    end

    test "with credentials, invalid param", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/favorites/create/wrong.json")

      assert json_response(conn, 400)
    end

    test "with credentials, invalid activity", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/favorites/create/1.json")

      assert json_response(conn, 500)
    end
  end

  describe "POST /api/favorites/destroy/:id" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/favorites/destroy/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      ActivityPub.like(current_user, object)

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/favorites/destroy/#{note_activity.id}.json")

      assert json_response(conn, 200)
    end
  end

  describe "POST /api/statuses/retweet/:id" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/statuses/retweet/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)

      request_path = "/api/statuses/retweet/#{note_activity.id}.json"

      response =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post(request_path)

      activity = Repo.get(Activity, note_activity.id)
      activity_user = Repo.get_by(User, ap_id: note_activity.data["actor"])

      assert json_response(response, 200) ==
               ActivityRepresenter.to_map(activity, %{user: activity_user, for: current_user})
    end
  end

  describe "POST /api/statuses/unretweet/:id" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/statuses/unretweet/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)

      request_path = "/api/statuses/retweet/#{note_activity.id}.json"

      _response =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post(request_path)

      request_path = String.replace(request_path, "retweet", "unretweet")

      response =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post(request_path)

      activity = Repo.get(Activity, note_activity.id)
      activity_user = Repo.get_by(User, ap_id: note_activity.data["actor"])

      assert json_response(response, 200) ==
               ActivityRepresenter.to_map(activity, %{user: activity_user, for: current_user})
    end
  end

  describe "POST /api/account/register" do
    test "it creates a new user", %{conn: conn} do
      data = %{
        "nickname" => "lain",
        "email" => "lain@wired.jp",
        "fullname" => "lain iwakura",
        "bio" => "close the world.",
        "password" => "bear",
        "confirm" => "bear"
      }

      conn =
        conn
        |> post("/api/account/register", data)

      user = json_response(conn, 200)

      fetched_user = Repo.get_by(User, nickname: "lain")
      assert user == UserView.render("show.json", %{user: fetched_user})
    end

    test "it returns errors on a problem", %{conn: conn} do
      data = %{
        "email" => "lain@wired.jp",
        "fullname" => "lain iwakura",
        "bio" => "close the world.",
        "password" => "bear",
        "confirm" => "bear"
      }

      conn =
        conn
        |> post("/api/account/register", data)

      errors = json_response(conn, 400)

      assert is_binary(errors["error"])
    end
  end

  describe "GET /api/externalprofile/show" do
    test "it returns the user", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/externalprofile/show", %{profileurl: other_user.ap_id})

      assert json_response(conn, 200) == UserView.render("show.json", %{user: other_user})
    end
  end

  describe "GET /api/statuses/followers" do
    test "it returns a user's followers", %{conn: conn} do
      user = insert(:user)
      follower_one = insert(:user)
      follower_two = insert(:user)
      _not_follower = insert(:user)

      {:ok, follower_one} = User.follow(follower_one, user)
      {:ok, follower_two} = User.follow(follower_two, user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/followers")

      expected = UserView.render("index.json", %{users: [follower_one, follower_two], for: user})
      result = json_response(conn, 200)
      assert Enum.sort(expected) == Enum.sort(result)
    end
  end

  describe "GET /api/statuses/friends" do
    test "it returns the logged in user's friends", %{conn: conn} do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      _not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends")

      expected = UserView.render("index.json", %{users: [followed_one, followed_two], for: user})
      result = json_response(conn, 200)
      assert Enum.sort(expected) == Enum.sort(result)
    end

    test "it returns a given user's friends with user_id", %{conn: conn} do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      _not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends", %{"user_id" => user.id})

      assert MapSet.equal?(
               MapSet.new(json_response(conn, 200)),
               MapSet.new(
                 UserView.render("index.json", %{users: [followed_one, followed_two], for: user})
               )
             )
    end

    test "it returns a given user's friends with screen_name", %{conn: conn} do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      _not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends", %{"screen_name" => user.nickname})

      assert MapSet.equal?(
               MapSet.new(json_response(conn, 200)),
               MapSet.new(
                 UserView.render("index.json", %{users: [followed_one, followed_two], for: user})
               )
             )
    end
  end

  describe "GET /friends/ids" do
    test "it returns a user's friends", %{conn: conn} do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      _not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/friends/ids")

      expected = [followed_one.id, followed_two.id]

      assert MapSet.equal?(
               MapSet.new(Poison.decode!(json_response(conn, 200))),
               MapSet.new(expected)
             )
    end
  end

  describe "POST /api/account/update_profile.json" do
    test "it updates a user's profile", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "name" => "new name",
          "description" => "new description"
        })

      user = Repo.get!(User, user.id)
      assert user.name == "new name"
      assert user.bio == "new description"

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it locks an account", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "locked" => "true"
        })

      user = Repo.get!(User, user.id)
      assert user.info.locked == true

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it unlocks an account", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "locked" => "false"
        })

      user = Repo.get!(User, user.id)
      assert user.info.locked == false

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end
  end

  defp valid_user(_context) do
    user = insert(:user)
    [user: user]
  end

  defp with_credentials(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    put_req_header(conn, "authorization", header_content)
  end

  describe "GET /api/search.json" do
    test "it returns search results", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu"})
      {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

      conn =
        conn
        |> get("/api/search.json", %{"q" => "2hu", "page" => "1", "rpp" => "1"})

      assert [status] = json_response(conn, 200)
      assert status["id"] == activity.id
    end
  end

  describe "GET /api/statusnet/tags/timeline/:tag.json" do
    test "it returns the tags timeline", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{nickname: "shp@shitposter.club"})

      {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about #2hu"})
      {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

      conn =
        conn
        |> get("/api/statusnet/tags/timeline/2hu.json")

      assert [status] = json_response(conn, 200)
      assert status["id"] == activity.id
    end
  end

  test "Convert newlines to <br> in bio", %{conn: conn} do
    user = insert(:user)

    _conn =
      conn
      |> assign(:user, user)
      |> post("/api/account/update_profile.json", %{
        "description" => "Hello,\r\nWorld! I\n am a test."
      })

    user = Repo.get!(User, user.id)
    assert user.bio == "Hello,<br>World! I<br> am a test."
  end

  describe "POST /api/pleroma/change_password" do
    setup [:valid_user]

    test "without credentials", %{conn: conn} do
      conn = post(conn, "/api/pleroma/change_password")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials and invalid password", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/change_password", %{
          "password" => "hi",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with credentials, valid password and new password and confirmation not matching", %{
      conn: conn,
      user: current_user
    } do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "newpass",
          "new_password_confirmation" => "notnewpass"
        })

      assert json_response(conn, 200) == %{
               "error" => "New password does not match confirmation."
             }
    end

    test "with credentials, valid password and invalid new password", %{
      conn: conn,
      user: current_user
    } do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "",
          "new_password_confirmation" => ""
        })

      assert json_response(conn, 200) == %{
               "error" => "New password can't be blank."
             }
    end

    test "with credentials, valid password and matching new password and confirmation", %{
      conn: conn,
      user: current_user
    } do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response(conn, 200) == %{"status" => "success"}
      fetched_user = Repo.get(User, current_user.id)
      assert Pbkdf2.checkpw("newpass", fetched_user.password_hash) == true
    end
  end

  describe "POST /api/pleroma/delete_account" do
    setup [:valid_user]

    test "without credentials", %{conn: conn} do
      conn = post(conn, "/api/pleroma/delete_account")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials and invalid password", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/delete_account", %{"password" => "hi"})

      assert json_response(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with credentials and valid password", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/pleroma/delete_account", %{"password" => "test"})

      assert json_response(conn, 200) == %{"status" => "success"}
      # Wait a second for the started task to end
      :timer.sleep(1000)
    end
  end

  describe "GET /api/pleroma/friend_requests" do
    test "it lists friend requests" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = Repo.get(User, user.id)
      other_user = Repo.get(User, other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/pleroma/friend_requests")

      assert [relationship] = json_response(conn, 200)
      assert other_user.id == relationship["id"]
    end
  end

  describe "POST /api/pleroma/friendships/approve" do
    test "it approves a friend request" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = Repo.get(User, user.id)
      other_user = Repo.get(User, other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/pleroma/friendships/approve", %{"user_id" => to_string(other_user.id)})

      assert relationship = json_response(conn, 200)
      assert other_user.id == relationship["id"]
      assert relationship["follows_you"] == true
    end
  end

  describe "POST /api/pleroma/friendships/deny" do
    test "it denies a friend request" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = Repo.get(User, user.id)
      other_user = Repo.get(User, other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/pleroma/friendships/deny", %{"user_id" => to_string(other_user.id)})

      assert relationship = json_response(conn, 200)
      assert other_user.id == relationship["id"]
      assert relationship["follows_you"] == false
    end
  end

  describe "GET /api/pleroma/search_user" do
    test "it returns users, ordered by similarity", %{conn: conn} do
      user = insert(:user, %{name: "eal"})
      user_two = insert(:user, %{name: "ean"})
      user_three = insert(:user, %{name: "ebn"})

      resp =
        conn
        |> get(twitter_api_search__path(conn, :search_user), query: "eal")
        |> json_response(200)

      assert length(resp) == 3
      assert [user.id, user_two.id, user_three.id] == Enum.map(resp, fn %{"id" => id} -> id end)
    end
  end
end
