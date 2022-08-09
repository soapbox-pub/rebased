# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.RuleControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Rule

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/rules" do
    test "sorts rules by priority", %{conn: conn} do
      %{id: id1} = Rule.create(%{text: "Example rule"})
      %{id: id2} = Rule.create(%{text: "Second rule", priority: 2})
      %{id: id3} = Rule.create(%{text: "Third rule", priority: 1})

      response =
        conn
        |> get("/api/pleroma/admin/rules")
        |> json_response_and_validate_schema(:ok)

      assert [%{"id" => ^id1}, %{"id" => ^id3}, %{"id" => ^id2}] = response
    end
  end

  describe "POST /api/pleroma/admin/rules" do
    test "creates a rule", %{conn: conn} do
      %{"id" => id} =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/rules", %{text: "Example rule"})
        |> json_response_and_validate_schema(:ok)

      assert %{text: "Example rule"} = Rule.get(id)
    end
  end

  describe "PATCH /api/pleroma/admin/rules" do
    test "edits a rule", %{conn: conn} do
      %{id: id} = Rule.create(%{text: "Example rule"})

      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/rules/#{id}", %{text: "There are no rules", priority: 2})
      |> json_response_and_validate_schema(:ok)

      assert %{text: "There are no rules", priority: 2} = Rule.get(id)
    end
  end

  describe "DELETE /api/pleroma/admin/rules" do
    test "deletes a rule", %{conn: conn} do
      %{id: id} = Rule.create(%{text: "Example rule"})

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/pleroma/admin/rules/#{id}")
      |> json_response_and_validate_schema(:ok)

      assert [] =
               Rule.query()
               |> Pleroma.Repo.all()
    end
  end
end
