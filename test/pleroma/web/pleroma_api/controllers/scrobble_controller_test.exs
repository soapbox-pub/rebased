# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ScrobbleControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.CommonAPI

  describe "POST /api/v1/pleroma/scrobble" do
    test "works correctly" do
      %{conn: conn} = oauth_access(["write"])

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/scrobble", %{
          "title" => "lain radio episode 1",
          "artist" => "lain",
          "album" => "lain radio",
          "length" => "180000",
          "url" => "https://www.last.fm/music/lain/lain+radio/lain+radio+episode+1"
        })

      assert %{"title" => "lain radio episode 1"} = json_response_and_validate_schema(conn, 200)
    end
  end

  describe "GET /api/v1/pleroma/accounts/:id/scrobbles" do
    test "works correctly" do
      %{user: user, conn: conn} = oauth_access(["read"])

      {:ok, _activity} =
        CommonAPI.listen(user, %{
          title: "lain radio episode 1",
          artist: "lain",
          album: "lain radio",
          url: "https://www.last.fm/music/lain/lain+radio/lain+radio+episode+1"
        })

      {:ok, _activity} =
        CommonAPI.listen(user, %{
          title: "lain radio episode 2",
          artist: "lain",
          album: "lain radio",
          url: "https://www.last.fm/music/lain/lain+radio/lain+radio+episode+2"
        })

      {:ok, _activity} =
        CommonAPI.listen(user, %{
          title: "lain radio episode 3",
          artist: "lain",
          album: "lain radio",
          url: "https://www.last.fm/music/lain/lain+radio/lain+radio+episode+3"
        })

      conn = get(conn, "/api/v1/pleroma/accounts/#{user.id}/scrobbles")

      result = json_response_and_validate_schema(conn, 200)

      assert length(result) == 3
    end
  end
end
