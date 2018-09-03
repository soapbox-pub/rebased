defmodule Pleroma.Web.NodeInfoTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  test "nodeinfo shows staff accounts", %{conn: conn} do
    user = insert(:user, %{local: true, info: %{"is_moderator" => true}})

    conn =
      conn
      |> get("/nodeinfo/2.0.json")

    assert result = json_response(conn, 200)

    assert user.ap_id in result["metadata"]["staffAccounts"]
  end
end
