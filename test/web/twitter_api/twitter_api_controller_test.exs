# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase
  alias Comeonin.Pbkdf2
  alias Ecto.Changeset
  alias Pleroma.Activity
  alias Pleroma.Builders.ActivityBuilder
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.Controller
  alias Pleroma.Web.TwitterAPI.NotificationView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.UserView

  import Mock
  import Pleroma.Factory
  import Swoosh.TestAssertions

  @banner "data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7"

  describe "POST /api/account/update_profile_banner" do
    test "it updates the banner", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post(authenticated_twitter_api__path(conn, :update_banner), %{"banner" => @banner})
      |> json_response(200)

      user = refresh_record(user)
      assert user.info.banner["type"] == "Image"
    end

    test "profile banner can be reset", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post(authenticated_twitter_api__path(conn, :update_banner), %{"banner" => ""})
      |> json_response(200)

      user = refresh_record(user)
      assert user.info.banner == %{}
    end
  end

  describe "POST /api/qvitter/update_background_image" do
    test "it updates the background", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post(authenticated_twitter_api__path(conn, :update_background), %{"img" => @banner})
      |> json_response(200)

      user = refresh_record(user)
      assert user.info.background["type"] == "Image"
    end

    test "background can be reset", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post(authenticated_twitter_api__path(conn, :update_background), %{"img" => ""})
      |> json_response(200)

      user = refresh_record(user)
      assert user.info.background == %{}
    end
  end

  describe "POST /api/account/verify_credentials" do
    setup [:valid_user]

    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/account/verify_credentials.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      response =
        conn
        |> with_credentials(user.nickname, "test")
        |> post("/api/account/verify_credentials.json")
        |> json_response(200)

      assert response ==
               UserView.render("show.json", %{user: user, token: response["token"], for: user})
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

      conn =
        conn_with_creds
        |> post(request_path)

      assert json_response(conn, 400) == error_response

      conn =
        conn_with_creds
        |> post(request_path, %{status: ""})

      assert json_response(conn, 400) == error_response

      conn =
        conn_with_creds
        |> post(request_path, %{status: " "})

      assert json_response(conn, 400) == error_response

      # we post with visibility private in order to avoid triggering relay
      conn =
        conn_with_creds
        |> post(request_path, %{status: "Nice meme.", visibility: "private"})

      assert json_response(conn, 200) ==
               ActivityView.render("activity.json", %{
                 activity: Repo.one(Activity),
                 user: user,
                 for: user
               })
    end
  end

  describe "GET /statuses/public_timeline.json" do
    setup [:valid_user]
    clear_config([:instance, :public])

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

    test "returns 403 to unauthenticated request when the instance is not public", %{conn: conn} do
      Pleroma.Config.put([:instance, :public], false)

      conn
      |> get("/api/statuses/public_timeline.json")
      |> json_response(403)
    end

    test "returns 200 to authenticated request when the instance is not public",
         %{conn: conn, user: user} do
      Pleroma.Config.put([:instance, :public], false)

      conn
      |> with_credentials(user.nickname, "test")
      |> get("/api/statuses/public_timeline.json")
      |> json_response(200)
    end

    test "returns 200 to unauthenticated request when the instance is public", %{conn: conn} do
      conn
      |> get("/api/statuses/public_timeline.json")
      |> json_response(200)
    end

    test "returns 200 to authenticated request when the instance is public",
         %{conn: conn, user: user} do
      conn
      |> with_credentials(user.nickname, "test")
      |> get("/api/statuses/public_timeline.json")
      |> json_response(200)
    end

    test_with_mock "treats user as unauthenticated if `assigns[:token]` is present but lacks `read` permission",
                   Controller,
                   [:passthrough],
                   [] do
      token = insert(:oauth_token, scopes: ["write"])

      build_conn()
      |> put_req_header("authorization", "Bearer #{token.token}")
      |> get("/api/statuses/public_timeline.json")
      |> json_response(200)

      assert called(Controller.public_timeline(%{assigns: %{user: nil}}, :_))
    end
  end

  describe "GET /statuses/public_and_external_timeline.json" do
    setup [:valid_user]
    clear_config([:instance, :public])

    test "returns 403 to unauthenticated request when the instance is not public", %{conn: conn} do
      Pleroma.Config.put([:instance, :public], false)

      conn
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(403)
    end

    test "returns 200 to authenticated request when the instance is not public",
         %{conn: conn, user: user} do
      Pleroma.Config.put([:instance, :public], false)

      conn
      |> with_credentials(user.nickname, "test")
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(200)
    end

    test "returns 200 to unauthenticated request when the instance is public", %{conn: conn} do
      conn
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(200)
    end

    test "returns 200 to authenticated request when the instance is public",
         %{conn: conn, user: user} do
      conn
      |> with_credentials(user.nickname, "test")
      |> get("/api/statuses/public_and_external_timeline.json")
      |> json_response(200)
    end
  end

  describe "GET /statuses/show/:id.json" do
    test "returns one status", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey!"})
      actor = User.get_cached_by_ap_id(activity.data["actor"])

      conn =
        conn
        |> get("/api/statuses/show/#{activity.id}.json")

      response = json_response(conn, 200)

      assert response == ActivityView.render("activity.json", %{activity: activity, user: actor})
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
        Changeset.change(current_user, following: [User.ap_followers(user)])
        |> Repo.update!()

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/friends_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10

      assert response ==
               Enum.map(returned_activities, fn activity ->
                 ActivityView.render("activity.json", %{
                   activity: activity,
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

    test "doesn't include DMs from blocked users", %{conn: conn} do
      blocker = insert(:user)
      blocked = insert(:user)
      user = insert(:user)
      {:ok, blocker} = User.block(blocker, blocked)

      {:ok, _blocked_direct} =
        CommonAPI.post(blocked, %{
          "status" => "Hi @#{blocker.nickname}!",
          "visibility" => "direct"
        })

      {:ok, direct} =
        CommonAPI.post(user, %{
          "status" => "Hi @#{blocker.nickname}!",
          "visibility" => "direct"
        })

      res_conn =
        conn
        |> assign(:user, blocker)
        |> get("/api/statuses/dm_timeline.json")

      [status] = json_response(res_conn, 200)
      assert status["id"] == direct.id
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
        CommonAPI.post(current_user, %{
          "status" => "why is tenshi eating a corndog so cute?",
          "visibility" => "public"
        })

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/mentions.json")

      response = json_response(conn, 200)

      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{
                 user: current_user,
                 for: current_user,
                 activity: activity
               })
    end

    test "does not show DMs in mentions timeline", %{conn: conn, user: current_user} do
      {:ok, _activity} =
        CommonAPI.post(current_user, %{
          "status" => "Have you guys ever seen how cute tenshi eating a corndog is?",
          "visibility" => "direct"
        })

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/mentions.json")

      response = json_response(conn, 200)

      assert Enum.empty?(response)
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

    test "muted user", %{conn: conn, user: current_user} do
      other_user = insert(:user)

      {:ok, current_user} = User.mute(current_user, other_user)

      {:ok, _activity} =
        ActivityBuilder.insert(%{"to" => [current_user.ap_id]}, %{user: other_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/statuses/notifications.json")

      assert json_response(conn, 200) == []
    end

    test "muted user with with_muted parameter", %{conn: conn, user: current_user} do
      other_user = insert(:user)

      {:ok, current_user} = User.mute(current_user, other_user)

      {:ok, _activity} =
        ActivityBuilder.insert(%{"to" => [current_user.ap_id]}, %{user: other_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/statuses/notifications.json", %{"with_muted" => "true"})

      assert length(json_response(conn, 200)) == 1
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

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})
    end

    test "with screen_name", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: user})

      conn = get(conn, "/api/statuses/user_timeline.json", %{"screen_name" => user.nickname})
      response = json_response(conn, 200)
      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1}, %{user: current_user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/user_timeline.json")

      response = json_response(conn, 200)

      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{
                 user: current_user,
                 for: current_user,
                 activity: activity
               })
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

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})
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

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})
    end

    test "with credentials with user_id, excluding RTs", %{conn: conn, user: current_user} do
      user = insert(:user)
      {:ok, activity} = ActivityBuilder.insert(%{"id" => 1, "type" => "Create"}, %{user: user})
      {:ok, _} = ActivityBuilder.insert(%{"id" => 2, "type" => "Announce"}, %{user: user})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/user_timeline.json", %{
          "user_id" => user.id,
          "include_rts" => "false"
        })

      response = json_response(conn, 200)

      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})

      conn =
        conn
        |> get("/api/statuses/user_timeline.json", %{"user_id" => user.id, "include_rts" => "0"})

      response = json_response(conn, 200)

      assert length(response) == 1

      assert Enum.at(response, 0) ==
               ActivityView.render("activity.json", %{user: user, activity: activity})
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

      current_user = User.get_cached_by_id(current_user.id)
      assert User.ap_followers(followed) in current_user.following

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: followed, for: current_user})
    end

    test "for restricted account", %{conn: conn, user: current_user} do
      followed = insert(:user, info: %User.Info{locked: true})

      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/friendships/create.json", %{user_id: followed.id})

      current_user = User.get_cached_by_id(current_user.id)
      followed = User.get_cached_by_id(followed.id)

      refute User.ap_followers(followed) in current_user.following

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

      current_user = User.get_cached_by_id(current_user.id)
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

      current_user = User.get_cached_by_id(current_user.id)
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

      current_user = User.get_cached_by_id(current_user.id)
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

      current_user = User.get_cached_by_id(current_user.id)
      assert is_map(current_user.avatar)

      assert json_response(conn, 200) ==
               UserView.render("show.json", %{user: current_user, for: current_user})
    end

    test "user avatar can be reset", %{conn: conn, user: current_user} do
      conn =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> post("/api/qvitter/update_avatar.json", %{img: ""})

      current_user = User.get_cached_by_id(current_user.id)
      assert current_user.avatar == nil

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
      response =
        conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/qvitter/mutes.json")
        |> json_response(200)

      assert [] = response
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

      assert json_response(conn, 400)
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
      object = Object.normalize(note_activity)
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

      activity = Activity.get_by_id(note_activity.id)
      activity_user = User.get_cached_by_ap_id(note_activity.data["actor"])

      assert json_response(response, 200) ==
               ActivityView.render("activity.json", %{
                 user: activity_user,
                 for: current_user,
                 activity: activity
               })
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

      activity = Activity.get_by_id(note_activity.id)
      activity_user = User.get_cached_by_ap_id(note_activity.data["actor"])

      assert json_response(response, 200) ==
               ActivityView.render("activity.json", %{
                 user: activity_user,
                 for: current_user,
                 activity: activity
               })
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

      fetched_user = User.get_cached_by_nickname("lain")
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

  describe "POST /api/account/password_reset, with valid parameters" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = post(conn, "/api/account/password_reset?email=#{user.email}")
      %{conn: conn, user: user}
    end

    test "it returns 204", %{conn: conn} do
      assert json_response(conn, :no_content)
    end

    test "it creates a PasswordResetToken record for user", %{user: user} do
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)
      assert token_record
    end

    test "it sends an email to user", %{user: user} do
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)

      email = Pleroma.Emails.UserEmail.password_reset_email(user, token_record.token)
      notify_email = Pleroma.Config.get([:instance, :notify_email])
      instance_name = Pleroma.Config.get([:instance, :name])

      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: email.html_body
      )
    end
  end

  describe "POST /api/account/password_reset, with invalid parameters" do
    setup [:valid_user]

    test "it returns 404 when user is not found", %{conn: conn, user: user} do
      conn = post(conn, "/api/account/password_reset?email=nonexisting_#{user.email}")
      assert conn.status == 404
      assert conn.resp_body == ""
    end

    test "it returns 400 when user is not local", %{conn: conn, user: user} do
      {:ok, user} = Repo.update(Changeset.change(user, local: false))
      conn = post(conn, "/api/account/password_reset?email=#{user.email}")
      assert conn.status == 400
      assert conn.resp_body == ""
    end
  end

  describe "GET /api/account/confirm_email/:id/:token" do
    setup do
      user = insert(:user)
      info_change = User.Info.confirmation_changeset(user.info, need_confirmation: true)

      {:ok, user} =
        user
        |> Changeset.change()
        |> Changeset.put_embed(:info, info_change)
        |> Repo.update()

      assert user.info.confirmation_pending

      [user: user]
    end

    test "it redirects to root url", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/#{user.id}/#{user.info.confirmation_token}")

      assert 302 == conn.status
    end

    test "it confirms the user account", %{conn: conn, user: user} do
      get(conn, "/api/account/confirm_email/#{user.id}/#{user.info.confirmation_token}")

      user = User.get_cached_by_id(user.id)

      refute user.info.confirmation_pending
      refute user.info.confirmation_token
    end

    test "it returns 500 if user cannot be found by id", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/0/#{user.info.confirmation_token}")

      assert 500 == conn.status
    end

    test "it returns 500 if token is invalid", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/#{user.id}/wrong_token")

      assert 500 == conn.status
    end
  end

  describe "POST /api/account/resend_confirmation_email" do
    setup do
      user = insert(:user)
      info_change = User.Info.confirmation_changeset(user.info, need_confirmation: true)

      {:ok, user} =
        user
        |> Changeset.change()
        |> Changeset.put_embed(:info, info_change)
        |> Repo.update()

      assert user.info.confirmation_pending

      [user: user]
    end

    clear_config([:instance, :account_activation_required]) do
      Pleroma.Config.put([:instance, :account_activation_required], true)
    end

    test "it returns 204 No Content", %{conn: conn, user: user} do
      conn
      |> assign(:user, user)
      |> post("/api/account/resend_confirmation_email?email=#{user.email}")
      |> json_response(:no_content)
    end

    test "it sends confirmation email", %{conn: conn, user: user} do
      conn
      |> assign(:user, user)
      |> post("/api/account/resend_confirmation_email?email=#{user.email}")

      email = Pleroma.Emails.UserEmail.account_confirmation_email(user)
      notify_email = Pleroma.Config.get([:instance, :notify_email])
      instance_name = Pleroma.Config.get([:instance, :name])

      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: email.html_body
      )
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

    test "it returns 20 followers per page", %{conn: conn} do
      user = insert(:user)
      followers = insert_list(21, :user)

      Enum.each(followers, fn follower ->
        User.follow(follower, user)
      end)

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/followers")

      result = json_response(res_conn, 200)
      assert length(result) == 20

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/followers?page=2")

      result = json_response(res_conn, 200)
      assert length(result) == 1
    end

    test "it returns a given user's followers with user_id", %{conn: conn} do
      user = insert(:user)
      follower_one = insert(:user)
      follower_two = insert(:user)
      not_follower = insert(:user)

      {:ok, follower_one} = User.follow(follower_one, user)
      {:ok, follower_two} = User.follow(follower_two, user)

      conn =
        conn
        |> assign(:user, not_follower)
        |> get("/api/statuses/followers", %{"user_id" => user.id})

      assert MapSet.equal?(
               MapSet.new(json_response(conn, 200)),
               MapSet.new(
                 UserView.render("index.json", %{
                   users: [follower_one, follower_two],
                   for: not_follower
                 })
               )
             )
    end

    test "it returns empty when hide_followers is set to true", %{conn: conn} do
      user = insert(:user, %{info: %{hide_followers: true}})
      follower_one = insert(:user)
      follower_two = insert(:user)
      not_follower = insert(:user)

      {:ok, _follower_one} = User.follow(follower_one, user)
      {:ok, _follower_two} = User.follow(follower_two, user)

      response =
        conn
        |> assign(:user, not_follower)
        |> get("/api/statuses/followers", %{"user_id" => user.id})
        |> json_response(200)

      assert [] == response
    end

    test "it returns the followers when hide_followers is set to true if requested by the user themselves",
         %{
           conn: conn
         } do
      user = insert(:user, %{info: %{hide_followers: true}})
      follower_one = insert(:user)
      follower_two = insert(:user)
      _not_follower = insert(:user)

      {:ok, _follower_one} = User.follow(follower_one, user)
      {:ok, _follower_two} = User.follow(follower_two, user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/followers", %{"user_id" => user.id})

      refute [] == json_response(conn, 200)
    end
  end

  describe "GET /api/statuses/blocks" do
    test "it returns the list of users blocked by requester", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, user} = User.block(user, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/blocks")

      expected = UserView.render("index.json", %{users: [other_user], for: user})
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

    test "it returns 20 friends per page, except if 'export' is set to true", %{conn: conn} do
      user = insert(:user)
      followeds = insert_list(21, :user)

      {:ok, user} =
        Enum.reduce(followeds, {:ok, user}, fn followed, {:ok, user} ->
          User.follow(user, followed)
        end)

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends")

      result = json_response(res_conn, 200)
      assert length(result) == 20

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends", %{page: 2})

      result = json_response(res_conn, 200)
      assert length(result) == 1

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends", %{all: true})

      result = json_response(res_conn, 200)
      assert length(result) == 21
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

    test "it returns empty when hide_follows is set to true", %{conn: conn} do
      user = insert(:user, %{info: %{hide_follows: true}})
      followed_one = insert(:user)
      followed_two = insert(:user)
      not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      conn =
        conn
        |> assign(:user, not_followed)
        |> get("/api/statuses/friends", %{"user_id" => user.id})

      assert [] == json_response(conn, 200)
    end

    test "it returns friends when hide_follows is set to true if the user themselves request it",
         %{
           conn: conn
         } do
      user = insert(:user, %{info: %{hide_follows: true}})
      followed_one = insert(:user)
      followed_two = insert(:user)
      _not_followed = insert(:user)

      {:ok, _user} = User.follow(user, followed_one)
      {:ok, _user} = User.follow(user, followed_two)

      response =
        conn
        |> assign(:user, user)
        |> get("/api/statuses/friends", %{"user_id" => user.id})
        |> json_response(200)

      refute [] == response
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
      user2 = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "name" => "new name",
          "description" => "hi @#{user2.nickname}"
        })

      user = Repo.get!(User, user.id)
      assert user.name == "new name"

      assert user.bio ==
               "hi <span class='h-card'><a data-user='#{user2.id}' class='u-url mention' href='#{
                 user2.ap_id
               }'>@<span>#{user2.nickname}</span></a></span>"

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it sets and un-sets hide_follows", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post("/api/account/update_profile.json", %{
        "hide_follows" => "true"
      })

      user = Repo.get!(User, user.id)
      assert user.info.hide_follows == true

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "hide_follows" => "false"
        })

      user = refresh_record(user)
      assert user.info.hide_follows == false
      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it sets and un-sets hide_followers", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post("/api/account/update_profile.json", %{
        "hide_followers" => "true"
      })

      user = Repo.get!(User, user.id)
      assert user.info.hide_followers == true

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "hide_followers" => "false"
        })

      user = Repo.get!(User, user.id)
      assert user.info.hide_followers == false
      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it sets and un-sets show_role", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> post("/api/account/update_profile.json", %{
        "show_role" => "true"
      })

      user = Repo.get!(User, user.id)
      assert user.info.show_role == true

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "show_role" => "false"
        })

      user = Repo.get!(User, user.id)
      assert user.info.show_role == false
      assert json_response(conn, 200) == UserView.render("user.json", %{user: user, for: user})
    end

    test "it sets and un-sets skip_thread_containment", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{"skip_thread_containment" => "true"})
        |> json_response(200)

      assert response["pleroma"]["skip_thread_containment"] == true
      user = refresh_record(user)
      assert user.info.skip_thread_containment

      response =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{"skip_thread_containment" => "false"})
        |> json_response(200)

      assert response["pleroma"]["skip_thread_containment"] == false
      refute refresh_record(user).info.skip_thread_containment
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

    # Broken before the change to class="emoji" and non-<img/> in the DB
    @tag :skip
    test "it formats emojos", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/account/update_profile.json", %{
          "bio" => "I love our :moominmamma:​"
        })

      assert response = json_response(conn, 200)

      assert %{
               "description" => "I love our :moominmamma:",
               "description_html" =>
                 ~s{I love our <img class="emoji" alt="moominmamma" title="moominmamma" src="} <>
                   _
             } = response

      conn =
        conn
        |> get("/api/users/show.json?user_id=#{user.nickname}")

      assert response == json_response(conn, 200)
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
      fetched_user = User.get_cached_by_id(current_user.id)
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

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/pleroma/friend_requests")

      assert [relationship] = json_response(conn, 200)
      assert other_user.id == relationship["id"]
    end

    test "requires 'read' permission", %{conn: conn} do
      token1 = insert(:oauth_token, scopes: ["write"])
      token2 = insert(:oauth_token, scopes: ["read"])

      for token <- [token1, token2] do
        conn =
          conn
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> get("/api/pleroma/friend_requests")

        if token == token1 do
          assert %{"error" => "Insufficient permissions: read."} == json_response(conn, 403)
        else
          assert json_response(conn, 200)
        end
      end
    end
  end

  describe "POST /api/pleroma/friendships/approve" do
    test "it approves a friend request" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/pleroma/friendships/approve", %{"user_id" => other_user.id})

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

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/pleroma/friendships/deny", %{"user_id" => other_user.id})

      assert relationship = json_response(conn, 200)
      assert other_user.id == relationship["id"]
      assert relationship["follows_you"] == false
    end
  end

  describe "GET /api/pleroma/search_user" do
    test "it returns users, ordered by similarity", %{conn: conn} do
      user = insert(:user, %{name: "eal"})
      user_two = insert(:user, %{name: "eal me"})
      _user_three = insert(:user, %{name: "zzz"})

      resp =
        conn
        |> get(twitter_api_search__path(conn, :search_user), query: "eal me")
        |> json_response(200)

      assert length(resp) == 2
      assert [user_two.id, user.id] == Enum.map(resp, fn %{"id" => id} -> id end)
    end
  end

  describe "POST /api/media/upload" do
    setup context do
      Pleroma.DataCase.ensure_local_uploader(context)
    end

    test "it performs the upload and sets `data[actor]` with AP id of uploader user", %{
      conn: conn
    } do
      user = insert(:user)

      upload_filename = "test/fixtures/image_tmp.jpg"
      File.cp!("test/fixtures/image.jpg", upload_filename)

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname(upload_filename),
        filename: "image.jpg"
      }

      response =
        conn
        |> assign(:user, user)
        |> put_req_header("content-type", "application/octet-stream")
        |> post("/api/media/upload", %{
          "media" => file
        })
        |> json_response(:ok)

      assert response["media_id"]
      object = Repo.get(Object, response["media_id"])
      assert object
      assert object.data["actor"] == User.ap_id(user)
    end
  end

  describe "POST /api/media/metadata/create" do
    setup do
      object = insert(:note)
      user = User.get_cached_by_ap_id(object.data["actor"])
      %{object: object, user: user}
    end

    test "it returns :forbidden status on attempt to modify someone else's upload", %{
      conn: conn,
      object: object
    } do
      initial_description = object.data["name"]
      another_user = insert(:user)

      conn
      |> assign(:user, another_user)
      |> post("/api/media/metadata/create", %{"media_id" => object.id})
      |> json_response(:forbidden)

      object = Repo.get(Object, object.id)
      assert object.data["name"] == initial_description
    end

    test "it updates `data[name]` of referenced Object with provided value", %{
      conn: conn,
      object: object,
      user: user
    } do
      description = "Informative description of the image. Initial value: #{object.data["name"]}}"

      conn
      |> assign(:user, user)
      |> post("/api/media/metadata/create", %{
        "media_id" => object.id,
        "alt_text" => %{"text" => description}
      })
      |> json_response(:no_content)

      object = Repo.get(Object, object.id)
      assert object.data["name"] == description
    end
  end

  describe "POST /api/statuses/user_timeline.json?user_id=:user_id&pinned=true" do
    test "it returns a list of pinned statuses", %{conn: conn} do
      Pleroma.Config.put([:instance, :max_pinned_statuses], 1)

      user = insert(:user, %{name: "egor"})
      {:ok, %{id: activity_id}} = CommonAPI.post(user, %{"status" => "HI!!!"})
      {:ok, _} = CommonAPI.pin(activity_id, user)

      resp =
        conn
        |> get("/api/statuses/user_timeline.json", %{user_id: user.id, pinned: true})
        |> json_response(200)

      assert length(resp) == 1
      assert [%{"id" => ^activity_id, "pinned" => true}] = resp
    end
  end

  describe "POST /api/statuses/pin/:id" do
    setup do
      Pleroma.Config.put([:instance, :max_pinned_statuses], 1)
      [user: insert(:user)]
    end

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/statuses/pin/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "test!"})

      request_path = "/api/statuses/pin/#{activity.id}.json"

      response =
        conn
        |> with_credentials(user.nickname, "test")
        |> post(request_path)

      user = refresh_record(user)

      assert json_response(response, 200) ==
               ActivityView.render("activity.json", %{user: user, for: user, activity: activity})
    end
  end

  describe "POST /api/statuses/unpin/:id" do
    setup do
      Pleroma.Config.put([:instance, :max_pinned_statuses], 1)
      [user: insert(:user)]
    end

    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post(conn, "/api/statuses/unpin/#{note_activity.id}.json")
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "test!"})
      {:ok, activity} = CommonAPI.pin(activity.id, user)

      request_path = "/api/statuses/unpin/#{activity.id}.json"

      response =
        conn
        |> with_credentials(user.nickname, "test")
        |> post(request_path)

      user = refresh_record(user)

      assert json_response(response, 200) ==
               ActivityView.render("activity.json", %{user: user, for: user, activity: activity})
    end
  end

  describe "GET /api/oauth_tokens" do
    setup do
      token = insert(:oauth_token) |> Repo.preload(:user)

      %{token: token}
    end

    test "renders list", %{token: token} do
      response =
        build_conn()
        |> assign(:user, token.user)
        |> get("/api/oauth_tokens")

      keys =
        json_response(response, 200)
        |> hd()
        |> Map.keys()

      assert keys -- ["id", "app_name", "valid_until"] == []
    end

    test "revoke token", %{token: token} do
      response =
        build_conn()
        |> assign(:user, token.user)
        |> delete("/api/oauth_tokens/#{token.id}")

      tokens = Token.get_user_tokens(token.user)

      assert tokens == []
      assert response.status == 201
    end
  end
end
