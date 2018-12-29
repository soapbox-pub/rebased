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
end
