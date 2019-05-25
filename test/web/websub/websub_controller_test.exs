# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Websub.WebsubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.Websub
  alias Pleroma.Web.Websub.WebsubClientSubscription

  test "websub subscription request", %{conn: conn} do
    user = insert(:user)

    path = Pleroma.Web.OStatus.pubsub_path(user)

    data = %{
      "hub.callback": "http://example.org/sub",
      "hub.mode": "subscribe",
      "hub.topic": Pleroma.Web.OStatus.feed_path(user),
      "hub.secret": "a random secret",
      "hub.lease_seconds": "100"
    }

    conn =
      conn
      |> post(path, data)

    assert response(conn, 202) == "Accepted"
  end

  test "websub subscription confirmation", %{conn: conn} do
    websub = insert(:websub_client_subscription)

    params = %{
      "hub.mode" => "subscribe",
      "hub.topic" => websub.topic,
      "hub.challenge" => "some challenge",
      "hub.lease_seconds" => "100"
    }

    conn =
      conn
      |> get("/push/subscriptions/#{websub.id}", params)

    websub = Repo.get(WebsubClientSubscription, websub.id)

    assert response(conn, 200) == "some challenge"
    assert websub.state == "accepted"
    assert_in_delta NaiveDateTime.diff(websub.valid_until, NaiveDateTime.utc_now()), 100, 5
  end

  describe "websub_incoming" do
    test "accepts incoming feed updates", %{conn: conn} do
      websub = insert(:websub_client_subscription)
      doc = "some stuff"
      signature = Websub.sign(websub.secret, doc)

      conn =
        conn
        |> put_req_header("x-hub-signature", "sha1=" <> signature)
        |> put_req_header("content-type", "application/atom+xml")
        |> post("/push/subscriptions/#{websub.id}", doc)

      assert response(conn, 200) == "OK"
    end

    test "rejects incoming feed updates with the wrong signature", %{conn: conn} do
      websub = insert(:websub_client_subscription)
      doc = "some stuff"
      signature = Websub.sign("wrong secret", doc)

      conn =
        conn
        |> put_req_header("x-hub-signature", "sha1=" <> signature)
        |> put_req_header("content-type", "application/atom+xml")
        |> post("/push/subscriptions/#{websub.id}", doc)

      assert response(conn, 500) == "Error"
    end
  end
end
