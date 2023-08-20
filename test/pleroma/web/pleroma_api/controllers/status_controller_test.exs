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
      {:ok, activity} = CommonAPI.post(post_user, %{status: "asdasd"})
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

  describe "getting quotes of a specified post" do
    setup do
      [current_user, user] = insert_pair(:user)
      %{user: current_user, conn: conn} = oauth_access(["read:statuses"], user: current_user)
      [current_user: current_user, user: user, conn: conn]
    end

    test "shows quotes of a post", %{conn: conn} do
      user = insert(:user)
      activity = insert(:note_activity)

      {:ok, quote_post} = CommonAPI.post(user, %{status: "quoat", quote_id: activity.id})

      response =
        conn
        |> get("/api/v1/pleroma/statuses/#{activity.id}/quotes")
        |> json_response_and_validate_schema(:ok)

      [status] = response

      assert length(response) == 1
      assert status["id"] == quote_post.id
    end

    test "returns 404 error when a post can't be seen", %{conn: conn} do
      activity = insert(:direct_note_activity)

      response =
        conn
        |> get("/api/v1/pleroma/statuses/#{activity.id}/quotes")

      assert json_response_and_validate_schema(response, 404) == %{"error" => "Record not found"}
    end

    test "returns 404 error when a post does not exist", %{conn: conn} do
      response =
        conn
        |> get("/api/v1/pleroma/statuses/idontexist/quotes")

      assert json_response_and_validate_schema(response, 404) == %{"error" => "Record not found"}
    end
  end
end
