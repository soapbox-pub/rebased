defmodule Pleroma.Web.Websub.WebsubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Repo
  alias Pleroma.Web.Websub.WebsubServerSubscription

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
    subscription = Repo.one!(WebsubServerSubscription)
    assert subscription.topic == Pleroma.Web.OStatus.feed_path(user)
    assert subscription.state == "requested"
    assert subscription.secret == "a random secret"
    assert subscription.callback == "http://example.org/sub"
    assert subscription.valid_until == NaiveDateTime.add(subscription.inserted_at, 100)
  end
end
