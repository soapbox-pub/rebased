# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.StatusControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "conversation subscribing" do
    setup do: oauth_access(["write:notifications"])

    setup do
      post_user = insert(:user)
      {:ok, activity} = CommonAPI.post(post_user, %{status: "HIE"})
      %{activity: activity}
    end

    test "subscribe to conversation", %{conn: conn, activity: activity} do
      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "pleroma" => %{"thread_subscribed" => true}} =
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/v1/pleroma/statuses/#{activity.id}/subscribe")
               |> json_response_and_validate_schema(200)
    end

    test "cannot subscribe to already subscribed conversation", %{
      conn: conn,
      user: user,
      activity: activity
    } do
      {:ok, _} = CommonAPI.add_subscription(user, activity)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/statuses/#{activity.id}/subscribe")

      assert json_response_and_validate_schema(conn, 400) == %{
               "error" => "conversation is already subscribed"
             }
    end

    test "unsubscribe conversation", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_subscription(user, activity)

      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "pleroma" => %{"thread_subscribed" => false}} =
               conn
               |> post("/api/v1/pleroma/statuses/#{activity.id}/unsubscribe")
               |> json_response_and_validate_schema(200)
    end
  end
end
