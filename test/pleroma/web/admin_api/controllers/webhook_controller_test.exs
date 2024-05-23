# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.WebhookControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Webhook

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/webhook" do
    test "lists existing webhooks", %{conn: conn} do
      Webhook.create(%{url: "https://example.com/webhook1", events: [:"report.created"]})
      Webhook.create(%{url: "https://example.com/webhook2", events: [:"account.created"]})

      response =
        conn
        |> get("/api/pleroma/admin/webhooks")
        |> json_response_and_validate_schema(:ok)

      assert length(response) == 2
    end
  end

  describe "POST /api/pleroma/admin/webhooks" do
    test "creates a webhook", %{conn: conn} do
      %{"id" => id} =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/webhooks", %{
          url: "http://example.com/webhook",
          events: ["account.created"]
        })
        |> json_response_and_validate_schema(:ok)

      assert %{url: "http://example.com/webhook", events: [:"account.created"]} = Webhook.get(id)
    end
  end

  describe "PATCH /api/pleroma/admin/webhooks" do
    test "edits a webhook", %{conn: conn} do
      %{id: id} =
        Webhook.create(%{url: "https://example.com/webhook1", events: [:"report.created"]})

      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/webhooks/#{id}", %{
        events: ["report.created", "account.created"]
      })
      |> json_response_and_validate_schema(:ok)

      assert %{events: [:"report.created", :"account.created"]} = Webhook.get(id)
    end

    test "can't edit an internal webhook", %{conn: conn} do
      %{id: id} =
        Webhook.create(%{url: "https://example.com/webhook1", events: [], internal: true},
          update_internal: true
        )

      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/pleroma/admin/webhooks/#{id}", %{
        events: ["report.created", "account.created"]
      })
      |> json_response_and_validate_schema(:forbidden)

      assert %{events: []} = Webhook.get(id)
    end
  end

  describe "DELETE /api/pleroma/admin/webhooks" do
    test "deletes a webhook", %{conn: conn} do
      %{id: id} =
        Webhook.create(%{url: "https://example.com/webhook1", events: [:"report.created"]})

      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/pleroma/admin/webhooks/#{id}")
      |> json_response_and_validate_schema(:ok)

      assert [] =
               Webhook
               |> Pleroma.Repo.all()
    end
  end
end
