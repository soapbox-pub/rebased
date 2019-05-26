defmodule Pleroma.Web.TwitterAPI.UtilControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "POST /api/pleroma/follow_import" do
    test "it returns HTTP 200", %{conn: conn} do
      user1 = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> assign(:user, user1)
        |> post("/api/pleroma/follow_import", %{"list" => "#{user2.ap_id}"})
        |> json_response(:ok)

      assert response == "job started"
    end

    test "it imports new-style mastodon follow lists", %{conn: conn} do
      user1 = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> assign(:user, user1)
        |> post("/api/pleroma/follow_import", %{
          "list" => "Account address,Show boosts\n#{user2.ap_id},true"
        })
        |> json_response(:ok)

      assert response == "job started"
    end

    test "requires 'follow' permission", %{conn: conn} do
      token1 = insert(:oauth_token, scopes: ["read", "write"])
      token2 = insert(:oauth_token, scopes: ["follow"])
      another_user = insert(:user)

      for token <- [token1, token2] do
        conn =
          conn
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> post("/api/pleroma/follow_import", %{"list" => "#{another_user.ap_id}"})

        if token == token1 do
          assert %{"error" => "Insufficient permissions: follow."} == json_response(conn, 403)
        else
          assert json_response(conn, 200)
        end
      end
    end
  end

  describe "POST /api/pleroma/blocks_import" do
    test "it returns HTTP 200", %{conn: conn} do
      user1 = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> assign(:user, user1)
        |> post("/api/pleroma/blocks_import", %{"list" => "#{user2.ap_id}"})
        |> json_response(:ok)

      assert response == "job started"
    end
  end

  describe "POST /api/pleroma/notifications/read" do
    test "it marks a single notification as read", %{conn: conn} do
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, activity1} = CommonAPI.post(user2, %{"status" => "hi @#{user1.nickname}"})
      {:ok, activity2} = CommonAPI.post(user2, %{"status" => "hi @#{user1.nickname}"})
      {:ok, [notification1]} = Notification.create_notifications(activity1)
      {:ok, [notification2]} = Notification.create_notifications(activity2)

      conn
      |> assign(:user, user1)
      |> post("/api/pleroma/notifications/read", %{"id" => "#{notification1.id}"})
      |> json_response(:ok)

      assert Repo.get(Notification, notification1.id).seen
      refute Repo.get(Notification, notification2.id).seen
    end
  end

  describe "PUT /api/pleroma/notification_settings" do
    test "it updates notification settings", %{conn: conn} do
      user = insert(:user)

      conn
      |> assign(:user, user)
      |> put("/api/pleroma/notification_settings", %{
        "followers" => false,
        "bar" => 1
      })
      |> json_response(:ok)

      user = Repo.get(User, user.id)

      assert %{
               "followers" => false,
               "follows" => true,
               "non_follows" => true,
               "non_followers" => true
             } == user.info.notification_settings
    end
  end

  describe "GET /api/statusnet/config.json" do
    test "returns the state of safe_dm_mentions flag", %{conn: conn} do
      option = Pleroma.Config.get([:instance, :safe_dm_mentions])
      Pleroma.Config.put([:instance, :safe_dm_mentions], true)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["safeDMMentionsEnabled"] == "1"

      Pleroma.Config.put([:instance, :safe_dm_mentions], false)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["safeDMMentionsEnabled"] == "0"

      Pleroma.Config.put([:instance, :safe_dm_mentions], option)
    end

    test "it returns the managed config", %{conn: conn} do
      Pleroma.Config.put([:instance, :managed_config], false)
      Pleroma.Config.put([:frontend_configurations, :pleroma_fe], %{theme: "asuka-hospital"})

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      refute response["site"]["pleromafe"]

      Pleroma.Config.put([:instance, :managed_config], true)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["pleromafe"] == %{"theme" => "asuka-hospital"}
    end
  end

  describe "GET /api/pleroma/frontend_configurations" do
    test "returns everything in :pleroma, :frontend_configurations", %{conn: conn} do
      config = [
        frontend_a: %{
          x: 1,
          y: 2
        },
        frontend_b: %{
          z: 3
        }
      ]

      Pleroma.Config.put(:frontend_configurations, config)

      response =
        conn
        |> get("/api/pleroma/frontend_configurations")
        |> json_response(:ok)

      assert response == Jason.encode!(config |> Enum.into(%{})) |> Jason.decode!()
    end
  end

  describe "/api/pleroma/emoji" do
    test "returns json with custom emoji with tags", %{conn: conn} do
      emoji =
        conn
        |> get("/api/pleroma/emoji")
        |> json_response(200)

      assert Enum.all?(emoji, fn
               {_key,
                %{
                  "image_url" => url,
                  "tags" => tags
                }} ->
                 is_binary(url) and is_list(tags)
             end)
    end
  end

  describe "GET /ostatus_subscribe?acct=...." do
    test "adds status to pleroma instance if the `acct` is a status", %{conn: conn} do
      conn =
        get(
          conn,
          "/ostatus_subscribe?acct=https://mastodon.social/users/emelie/statuses/101849165031453009"
        )

      assert redirected_to(conn) =~ "/notice/"
    end

    test "show follow account page if the `acct` is a account link", %{conn: conn} do
      response =
        get(
          conn,
          "/ostatus_subscribe?acct=https://mastodon.social/users/emelie"
        )

      assert html_response(response, 200) =~ "Log in to follow"
    end
  end

  test "GET /api/pleroma/healthcheck", %{conn: conn} do
    conn = get(conn, "/api/pleroma/healthcheck")

    assert conn.status in [200, 503]
  end

  describe "POST /api/pleroma/disable_account" do
    test "it returns HTTP 200", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/disable_account", %{"password" => "test"})
        |> json_response(:ok)

      assert response == %{"status" => "success"}

      user = User.get_cached_by_id(user.id)

      assert user.info.deactivated == true
    end
  end
end
