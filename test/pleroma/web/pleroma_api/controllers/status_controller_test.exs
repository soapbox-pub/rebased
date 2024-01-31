# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.StatusControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

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
