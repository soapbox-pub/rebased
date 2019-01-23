defmodule Pleroma.Web.TwitterAPI.UtilControllerTest do
  use Pleroma.Web.ConnCase

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

  describe "GET /api/pleroma/frontent_configurations" do
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
