# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InviteControllerTest do
  use Pleroma.Web.ConnCase, async: false

  import Pleroma.Factory

  alias Pleroma.Repo
  alias Pleroma.UserInviteToken

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "POST /api/pleroma/admin/users/email_invite, with valid config" do
    setup do
      clear_config([:instance, :registrations_open], false)
      clear_config([:instance, :invites_enabled], true)
      clear_config([:instance, :admin_privileges], [:users_manage_invites])
    end

    test "returns 403 if not privileged with :users_manage_invites", %{conn: conn} do
      clear_config([:instance, :admin_privileges], [])

      conn =
        conn
        |> put_req_header("content-type", "application/json;charset=utf-8")
        |> post("/api/pleroma/admin/users/email_invite", %{
          email: "foo@bar.com",
          name: "J. D."
        })

      assert json_response(conn, :forbidden)
    end

    test "sends invitation and returns 204", %{admin: admin, conn: conn} do
      recipient_email = "foo@bar.com"
      recipient_name = "J. D."

      conn =
        conn
        |> put_req_header("content-type", "application/json;charset=utf-8")
        |> post("/api/pleroma/admin/users/email_invite", %{
          email: recipient_email,
          name: recipient_name
        })

      assert json_response_and_validate_schema(conn, :no_content)

      token_record = List.last(Repo.all(Pleroma.UserInviteToken))
      assert token_record
      refute token_record.used

      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      email =
        Pleroma.Emails.UserEmail.user_invitation_email(
          admin,
          token_record,
          recipient_email,
          recipient_name
        )

      Swoosh.TestAssertions.assert_email_sent(
        from: {instance_name, notify_email},
        to: {recipient_name, recipient_email},
        html_body: email.html_body
      )
    end

    test "it returns 403 if requested by a non-admin" do
      non_admin_user = insert(:user)
      token = insert(:oauth_token, user: non_admin_user)

      conn =
        build_conn()
        |> assign(:user, non_admin_user)
        |> assign(:token, token)
        |> put_req_header("content-type", "application/json;charset=utf-8")
        |> post("/api/pleroma/admin/users/email_invite", %{
          email: "foo@bar.com",
          name: "JD"
        })

      assert json_response(conn, :forbidden)
    end

    test "email with +", %{conn: conn, admin: admin} do
      recipient_email = "foo+bar@baz.com"

      conn
      |> put_req_header("content-type", "application/json;charset=utf-8")
      |> post("/api/pleroma/admin/users/email_invite", %{email: recipient_email})
      |> json_response_and_validate_schema(:no_content)

      token_record =
        Pleroma.UserInviteToken
        |> Repo.all()
        |> List.last()

      assert token_record
      refute token_record.used

      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      email =
        Pleroma.Emails.UserEmail.user_invitation_email(
          admin,
          token_record,
          recipient_email
        )

      Swoosh.TestAssertions.assert_email_sent(
        from: {instance_name, notify_email},
        to: recipient_email,
        html_body: email.html_body
      )
    end
  end

  describe "POST /api/pleroma/admin/users/email_invite, with invalid config" do
    setup do
      clear_config([:instance, :registrations_open])
      clear_config([:instance, :invites_enabled])
      clear_config([:instance, :admin_privileges], [:users_manage_invites])
    end

    test "it returns 500 if `invites_enabled` is not enabled", %{conn: conn} do
      clear_config([:instance, :registrations_open], false)
      clear_config([:instance, :invites_enabled], false)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/email_invite", %{
          email: "foo@bar.com",
          name: "JD"
        })

      assert json_response_and_validate_schema(conn, :bad_request) ==
               %{
                 "error" =>
                   "To send invites you need to set the `invites_enabled` option to true."
               }
    end

    test "it returns 500 if `registrations_open` is enabled", %{conn: conn} do
      clear_config([:instance, :registrations_open], true)
      clear_config([:instance, :invites_enabled], true)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/email_invite", %{
          email: "foo@bar.com",
          name: "JD"
        })

      assert json_response_and_validate_schema(conn, :bad_request) ==
               %{
                 "error" =>
                   "To send invites you need to set the `registrations_open` option to false."
               }
    end
  end

  describe "POST /api/pleroma/admin/users/invite_token" do
    setup do
      clear_config([:instance, :admin_privileges], [:users_manage_invites])
    end

    test "returns 403 if not privileged with :users_manage_invites", %{conn: conn} do
      clear_config([:instance, :admin_privileges], [])

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/invite_token")

      assert json_response(conn, :forbidden)
    end

    test "without options", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/invite_token")

      invite_json = json_response_and_validate_schema(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      refute invite.expires_at
      refute invite.max_use
      assert invite.invite_type == "one_time"
    end

    test "with expires_at", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/invite_token", %{
          "expires_at" => Date.to_string(Date.utc_today())
        })

      invite_json = json_response_and_validate_schema(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])

      refute invite.used
      assert invite.expires_at == Date.utc_today()
      refute invite.max_use
      assert invite.invite_type == "date_limited"
    end

    test "with max_use", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/invite_token", %{"max_use" => 150})

      invite_json = json_response_and_validate_schema(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      refute invite.expires_at
      assert invite.max_use == 150
      assert invite.invite_type == "reusable"
    end

    test "with max use and expires_at", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/invite_token", %{
          "max_use" => 150,
          "expires_at" => Date.to_string(Date.utc_today())
        })

      invite_json = json_response_and_validate_schema(conn, 200)
      invite = UserInviteToken.find_by_token!(invite_json["token"])
      refute invite.used
      assert invite.expires_at == Date.utc_today()
      assert invite.max_use == 150
      assert invite.invite_type == "reusable_date_limited"
    end
  end

  describe "GET /api/pleroma/admin/users/invites" do
    setup do
      clear_config([:instance, :admin_privileges], [:users_manage_invites])
    end

    test "returns 403 if not privileged with :users_manage_invites", %{conn: conn} do
      clear_config([:instance, :admin_privileges], [])

      conn = get(conn, "/api/pleroma/admin/users/invites")

      assert json_response(conn, :forbidden)
    end

    test "no invites", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/users/invites")

      assert json_response_and_validate_schema(conn, 200) == %{"invites" => []}
    end

    test "with invite", %{conn: conn} do
      {:ok, invite} = UserInviteToken.create_invite()

      conn = get(conn, "/api/pleroma/admin/users/invites")

      assert json_response_and_validate_schema(conn, 200) == %{
               "invites" => [
                 %{
                   "expires_at" => nil,
                   "id" => invite.id,
                   "invite_type" => "one_time",
                   "max_use" => nil,
                   "token" => invite.token,
                   "used" => false,
                   "uses" => 0
                 }
               ]
             }
    end
  end

  describe "POST /api/pleroma/admin/users/revoke_invite" do
    setup do
      clear_config([:instance, :admin_privileges], [:users_manage_invites])
    end

    test "returns 403 if not privileged with :users_manage_invites", %{conn: conn} do
      clear_config([:instance, :admin_privileges], [])

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => "foo"})

      assert json_response(conn, :forbidden)
    end

    test "with token", %{conn: conn} do
      {:ok, invite} = UserInviteToken.create_invite()

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => invite.token})

      assert json_response_and_validate_schema(conn, 200) == %{
               "expires_at" => nil,
               "id" => invite.id,
               "invite_type" => "one_time",
               "max_use" => nil,
               "token" => invite.token,
               "used" => true,
               "uses" => 0
             }
    end

    test "with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/users/revoke_invite", %{"token" => "foo"})

      assert json_response_and_validate_schema(conn, :not_found) == %{"error" => "Not found"}
    end
  end
end
