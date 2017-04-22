defmodule Pleroma.Web.Websub.WebsubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  test "websub subscription request", %{conn: conn} do
    user = insert(:user)

    path = Pleroma.Web.OStatus.pubsub_path(user)

    data = %{
      "hub.callback": "http://example.org/sub",
      "hub.mode": "subscription",
      "hub.topic": Pleroma.Web.OStatus.feed_path(user),
      "hub.secret": "a random secret",
      "hub.lease_seconds": "100"
    }

    conn = conn
    |> post(path, data)

    assert response(conn, 202) == "Accepted"
  end
end
