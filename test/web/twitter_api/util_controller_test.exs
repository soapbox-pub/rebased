defmodule Pleroma.Web.TwitterAPI.UtilControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

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

  describe "GET /api/statusnet/config.json" do
    test "it returns the managed config", %{conn: conn} do
      Pleroma.Config.put([:instance, :managed_config], false)
      Pleroma.Config.put([:fe], theme: "rei-ayanami-towel")

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

      assert response["site"]["pleromafe"]
    end

    test "if :pleroma, :fe is false, it returns the new style config settings", %{conn: conn} do
      Pleroma.Config.put([:instance, :managed_config], true)
      Pleroma.Config.put([:fe, :theme], "rei-ayanami-towel")
      Pleroma.Config.put([:frontend_configurations, :pleroma_fe], %{theme: "asuka-hospital"})

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["pleromafe"]["theme"] == "rei-ayanami-towel"

      Pleroma.Config.put([:fe], false)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["pleromafe"]["theme"] == "asuka-hospital"
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
end
