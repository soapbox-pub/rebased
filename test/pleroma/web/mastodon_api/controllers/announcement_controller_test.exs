# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.AnnouncementReadRelationship

  describe "GET /api/v1/announcements" do
    test "it lists all announcements" do
      %{id: id} = insert(:announcement)

      response =
        build_conn()
        |> get("/api/v1/announcements")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id}] = response
      refute Map.has_key?(Enum.at(response, 0), "read")
    end

    test "when authenticated, also expose read property" do
      %{id: id} = insert(:announcement)

      %{conn: conn} = oauth_access(["read:accounts"])

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

  describe "GET /api/v1/announcements/:id" do
    test "it shows one announcement" do
      %{id: id} = insert(:announcement)

      response =
        build_conn()
        |> get("/api/v1/announcements/#{id}")
        |> json_response_and_validate_schema(:ok)

      assert %{"id" => ^id} = response
      refute Map.has_key?(response, "read")
    end

    test "it gives 404 for non-existent announcements" do
      %{id: id} = insert(:announcement)

      _response =
        build_conn()
        |> get("/api/v1/announcements/#{id}xxx")
        |> json_response_and_validate_schema(:not_found)
    end

    test "when authenticated, also expose read property" do
      %{id: id} = insert(:announcement)

      %{conn: conn} = oauth_access(["read:accounts"])

      response =
        conn
        |> get("/api/v1/announcements/#{id}")
        |> json_response_and_validate_schema(:ok)

      assert %{"id" => ^id, "read" => false} = response
    end

    test "when authenticated and announcement is read by user" do
      %{id: id} = announcement = insert(:announcement)
      user = insert(:user)

      AnnouncementReadRelationship.mark_read(user, announcement)

      %{conn: conn} = oauth_access(["read:accounts"], user: user)

      response =
        conn
        |> get("/api/v1/announcements/#{id}")
        |> json_response_and_validate_schema(:ok)

      assert %{"id" => ^id, "read" => true} = response
    end
  end
end
