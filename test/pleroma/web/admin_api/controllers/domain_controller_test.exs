# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.DomainControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Domain

  setup do
    clear_config([Pleroma.Web.WebFinger, :domain], "example.com")

    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/domains" do
    test "list created domains", %{conn: conn} do
      _domain =
        Domain.create(%{
          domain: "pleroma.mkljczk.pl",
          public: true
        })

      _domain =
        Domain.create(%{
          domain: "pleroma2.mkljczk.pl"
        })

      conn = get(conn, "/api/pleroma/admin/domains")

      [
        %{
          "id" => _id,
          "domain" => "pleroma.mkljczk.pl",
          "public" => true
        },
        %{
          "id" => _id2,
          "domain" => "pleroma2.mkljczk.pl",
          "public" => false
        }
      ] = json_response_and_validate_schema(conn, 200)
    end
  end

  describe "POST /api/pleroma/admin/domains" do
    test "create a valid domain", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/domains", %{
          domain: "pleroma.mkljczk.pl",
          public: true
        })

      %{
        "id" => _id,
        "domain" => "pleroma.mkljczk.pl",
        "public" => true
      } = json_response_and_validate_schema(conn, 200)
    end

    test "create a domain the same as host", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/domains", %{
          domain: "example.com",
          public: false
        })

      %{"error" => "invalid_domain"} = json_response_and_validate_schema(conn, 400)
    end

    test "create duplicate domains", %{conn: conn} do
      Domain.create(%{
        domain: "pleroma.mkljczk.pl",
        public: true
      })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/domains", %{
          domain: "pleroma.mkljczk.pl",
          public: false
        })

      assert json_response_and_validate_schema(conn, 400)
    end
  end

  describe "PATCH /api/pleroma/admin/domains/:id" do
    test "update domain privacy", %{conn: conn} do
      {:ok, %{id: domain_id}} =
        Domain.create(%{
          domain: "pleroma.mkljczk.pl",
          public: true
        })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/domains/#{domain_id}", %{
          public: false
        })

      %{
        "id" => _id,
        "domain" => "pleroma.mkljczk.pl",
        "public" => false
      } = json_response_and_validate_schema(conn, 200)
    end

    test "doesn't update domain name", %{conn: conn} do
      {:ok, %{id: domain_id}} =
        Domain.create(%{
          domain: "plemora.mkljczk.pl",
          public: true
        })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/pleroma/admin/domains/#{domain_id}", %{
          domain: "pleroma.mkljczk.pl"
        })

      %{
        "id" => _id,
        "domain" => "plemora.mkljczk.pl",
        "public" => true
      } = json_response_and_validate_schema(conn, 200)
    end
  end

  describe "DELETE /api/pleroma/admin/domains/:id" do
    test "delete a domain", %{conn: conn} do
      {:ok, %{id: domain_id}} =
        Domain.create(%{
          domain: "pleroma.mkljczk.pl",
          public: true
        })

      conn =
        conn
        |> delete("/api/pleroma/admin/domains/#{domain_id}")

      %{} = json_response_and_validate_schema(conn, 200)

      domains = Domain.list()

      assert length(domains) == 0
    end
  end
end
