# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AnnouncementControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Announcement
  alias Pleroma.AnnouncementReadRelationship

  describe "GET /api/v1/announcements" do
    setup do
      %{conn: conn} = oauth_access([])
      {:ok, conn: conn}
    end

    test "it does not allow guests", %{conn: conn} do
      _response =
        conn
        |> assign(:token, nil)
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:forbidden)
    end

    test "it allows users with scopes" do
      %{conn: conn} = oauth_access(["read:accounts"])

      _response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)
    end

    test "it lists all announcements", %{conn: conn} do
      %{id: id} = insert(:announcement)

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id}] = response
    end

    test "it returns time with utc timezone", %{conn: conn} do
      start_time =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-999_999, :second)
        |> NaiveDateTime.truncate(:second)

      end_time =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(999_999, :second)
        |> NaiveDateTime.truncate(:second)

      %{id: id} = insert(:announcement, %{starts_at: start_time, ends_at: end_time})

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id}] = [announcement] = response

      assert String.ends_with?(announcement["starts_at"], "Z")
      assert String.ends_with?(announcement["ends_at"], "Z")
    end

    test "it does not list announcements starting after current time", %{conn: conn} do
      time = NaiveDateTime.utc_now() |> NaiveDateTime.add(999_999, :second)
      insert(:announcement, starts_at: time)

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [] = response
    end

    test "it does not list announcements ending before current time", %{conn: conn} do
      time = NaiveDateTime.utc_now() |> NaiveDateTime.add(-999_999, :second)
      insert(:announcement, ends_at: time)

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [] = response
    end

    test "when authenticated, also expose read property", %{conn: conn} do
      %{id: id} = insert(:announcement)

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id, "read" => false}] = response
    end

    test "when authenticated and announcement is read by user" do
      %{id: id} = announcement = insert(:announcement)
      user = insert(:user)

      AnnouncementReadRelationship.mark_read(user, announcement)

      %{conn: conn} = oauth_access(["read:accounts"], user: user)

      response =
        conn
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id, "read" => true}] = response
    end
  end

  describe "POST /api/v1/announcements/:id/dismiss" do
    setup do: oauth_access(["write:accounts"])

    test "it requires auth", %{conn: conn} do
      %{id: id} = insert(:announcement)

      _response =
        conn
        |> assign(:token, nil)
        |> post("/api/v1/announcements/#{id}/dismiss")
        |> json_response_and_validate_schema(:forbidden)
    end

    test "it requires write:accounts oauth scope" do
      %{id: id} = insert(:announcement)

      %{conn: conn} = oauth_access(["read:accounts"])

      _response =
        conn
        |> post("/api/v1/announcements/#{id}/dismiss")
        |> json_response_and_validate_schema(:forbidden)
    end

    test "it gives 404 for non-existent announcements", %{conn: conn} do
      %{id: id} = insert(:announcement)

      _response =
        conn
        |> post("/api/v1/announcements/#{id}xxx/dismiss")
        |> json_response_and_validate_schema(:not_found)
    end

    test "it marks announcement as read", %{user: user, conn: conn} do
      %{id: id} = announcement = insert(:announcement)

      refute Announcement.read_by?(announcement, user)

      _response =
        conn
        |> post("/api/v1/announcements/#{id}/dismiss")
        |> json_response_and_validate_schema(:ok)

      assert Announcement.read_by?(announcement, user)
    end
  end
end
