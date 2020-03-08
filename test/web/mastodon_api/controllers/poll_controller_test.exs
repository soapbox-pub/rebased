# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "GET /api/v1/polls/:id" do
    setup do: oauth_access(["read:statuses"])

    test "returns poll entity for object id", %{user: user, conn: conn} do
      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Pleroma does",
          "poll" => %{"options" => ["what Mastodon't", "n't what Mastodoes"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      conn = get(conn, "/api/v1/polls/#{object.id}")

      response = json_response(conn, 200)
      id = to_string(object.id)
      assert %{"id" => ^id, "expired" => false, "multiple" => false} = response
    end

    test "does not expose polls for private statuses", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "Pleroma does",
          "poll" => %{"options" => ["what Mastodon't", "n't what Mastodoes"], "expires_in" => 20},
          "visibility" => "private"
        })

      object = Object.normalize(activity)

      conn = get(conn, "/api/v1/polls/#{object.id}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/polls/:id/votes" do
    setup do: oauth_access(["write:statuses"])

    test "votes are added to the poll", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "A very delicious sandwich",
          "poll" => %{
            "options" => ["Lettuce", "Grilled Bacon", "Tomato"],
            "expires_in" => 20,
            "multiple" => true
          }
        })

      object = Object.normalize(activity)

      conn = post(conn, "/api/v1/polls/#{object.id}/votes", %{"choices" => [0, 1, 2]})

      assert json_response(conn, 200)
      object = Object.get_by_id(object.id)

      assert Enum.all?(object.data["anyOf"], fn %{"replies" => %{"totalItems" => total_items}} ->
               total_items == 1
             end)
    end

    test "author can't vote", %{user: user, conn: conn} do
      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      assert conn
             |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [1]})
             |> json_response(422) == %{"error" => "Poll's author can't vote"}

      object = Object.get_by_id(object.id)

      refute Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 1
    end

    test "does not allow multiple choices on a single-choice question", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "The glass is",
          "poll" => %{"options" => ["half empty", "half full"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      assert conn
             |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [0, 1]})
             |> json_response(422) == %{"error" => "Too many choices"}

      object = Object.get_by_id(object.id)

      refute Enum.any?(object.data["oneOf"], fn %{"replies" => %{"totalItems" => total_items}} ->
               total_items == 1
             end)
    end

    test "does not allow choice index to be greater than options count", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      conn = post(conn, "/api/v1/polls/#{object.id}/votes", %{"choices" => [2]})

      assert json_response(conn, 422) == %{"error" => "Invalid indices"}
    end

    test "returns 404 error when object is not exist", %{conn: conn} do
      conn = post(conn, "/api/v1/polls/1/votes", %{"choices" => [0]})

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end

    test "returns 404 when poll is private and not available for user", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(other_user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20},
          "visibility" => "private"
        })

      object = Object.normalize(activity)

      conn = post(conn, "/api/v1/polls/#{object.id}/votes", %{"choices" => [0]})

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end
  end
end
