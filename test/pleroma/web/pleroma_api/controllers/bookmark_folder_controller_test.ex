# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.BookmarkFolderControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.BookmarkFolder
  # alias Pleroma.Object
  # alias Pleroma.Tests.Helpers
  # alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  # alias Pleroma.User
  # alias Pleroma.Web.ActivityPub.ActivityPub
  # alias Pleroma.Web.CommonAPI

  # import Mox
  import Pleroma.Factory

  describe "GET /api/v1/pleroma/bookmark_folders" do
    setup do: oauth_access(["read:bookmarks"])

    test "it lists bookmark folders", %{conn: conn, user: user} do
      {:ok, folder} = BookmarkFolder.create(user.id, "Bookmark folder")

      folder_id = folder.id

      result =
        conn
        |> get("/api/v1/pleroma/bookmark_folders")
        |> json_response_and_validate_schema(200)

      assert [
               %{
                 "id" => ^folder_id,
                 "name" => "Bookmark folder",
                 "emoji" => nil,
                 "emoji_url" => nil
               }
             ] = result
    end
  end

  describe "POST /api/v1/pleroma/bookmark_folders" do
    setup do: oauth_access(["write:bookmarks"])

    test "it creates a bookmark folder", %{conn: conn} do
      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/bookmark_folders", %{
          name: "Bookmark folder",
          emoji: "📁"
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "name" => "Bookmark folder",
               "emoji" => "📁",
               "emoji_url" => nil
             } = result
    end

    test "it creates a bookmark folder with custom emoji", %{conn: conn} do
      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/bookmark_folders", %{
          name: "Bookmark folder",
          emoji: ":firefox:"
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "name" => "Bookmark folder",
               "emoji" => ":firefox:",
               "emoji_url" => "http://localhost:4001/emoji/Firefox.gif"
             } = result
    end

    test "it returns error for invalid emoji", %{conn: conn} do
      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/bookmark_folders", %{
          name: "Bookmark folder",
          emoji: "not an emoji"
        })
        |> json_response_and_validate_schema(422)

      assert %{"error" => "Invalid emoji"} = result
    end
  end

  describe "PATCH /api/v1/pleroma/bookmark_folders/:id" do
    setup do: oauth_access(["write:bookmarks"])

    test "it updates a bookmark folder", %{conn: conn, user: user} do
      {:ok, folder} = BookmarkFolder.create(user.id, "Bookmark folder")

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/pleroma/bookmark_folders/#{folder.id}", %{
          name: "bookmark folder"
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "name" => "bookmark folder"
             } = result
    end

    test "it returns error when updating others' folders", %{conn: conn} do
      other_user = insert(:user)

      {:ok, folder} = BookmarkFolder.create(other_user.id, "Bookmark folder")

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/pleroma/bookmark_folders/#{folder.id}", %{
          name: "bookmark folder"
        })
        |> json_response_and_validate_schema(403)

      assert %{
               "error" => "Access denied"
             } = result
    end
  end

  describe "DELETE /api/v1/pleroma/bookmark_folders/:id" do
    setup do: oauth_access(["write:bookmarks"])

    test "it deleting a bookmark folder", %{conn: conn, user: user} do
      {:ok, folder} = BookmarkFolder.create(user.id, "Bookmark folder")

      assert conn
             |> delete("/api/v1/pleroma/bookmark_folders/#{folder.id}")
             |> json_response_and_validate_schema(200)

      folders = BookmarkFolder.for_user(user.id)

      assert length(folders) == 0
    end

    test "it returns error when deleting others' folders", %{conn: conn} do
      other_user = insert(:user)

      {:ok, folder} = BookmarkFolder.create(other_user.id, "Bookmark folder")

      result =
        conn
        |> patch("/api/v1/pleroma/bookmark_folders/#{folder.id}")
        |> json_response_and_validate_schema(403)

      assert %{
               "error" => "Access denied"
             } = result
    end
  end
end
