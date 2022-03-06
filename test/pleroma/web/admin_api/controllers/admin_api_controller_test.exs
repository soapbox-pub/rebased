# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Swoosh.TestAssertions

  alias Pleroma.Activity
  alias Pleroma.MFA
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  test "with valid `admin_token` query parameter, skips OAuth scopes check" do
    clear_config([:admin_token], "password123")

    user = insert(:user)

    conn = get(build_conn(), "/api/pleroma/admin/users/#{user.nickname}?admin_token=password123")

    assert json_response(conn, 200)
  end

  test "GET /api/pleroma/admin/users/:nickname requires admin:read:accounts or broader scope",
       %{admin: admin} do
    user = insert(:user)
    url = "/api/pleroma/admin/users/#{user.nickname}"

    good_token1 = insert(:oauth_token, user: admin, scopes: ["admin"])
    good_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read"])
    good_token3 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts"])

    bad_token1 = insert(:oauth_token, user: admin, scopes: ["read:accounts"])
    bad_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts:partial"])
    bad_token3 = nil

    for good_token <- [good_token1, good_token2, good_token3] do
      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, good_token)
        |> get(url)

      assert json_response(conn, 200)
    end

    for good_token <- [good_token1, good_token2, good_token3] do
      conn =
        build_conn()
        |> assign(:user, nil)
        |> assign(:token, good_token)
        |> get(url)

      assert json_response(conn, :forbidden)
    end

    for bad_token <- [bad_token1, bad_token2, bad_token3] do
      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, bad_token)
        |> get(url)

      assert json_response(conn, :forbidden)
    end
  end

  describe "PUT /api/pleroma/admin/users/tag" do
    setup %{conn: conn} do
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=" <>
            "#{user2.nickname}&tags[]=foo&tags[]=bar"
        )

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it appends specified tags to users with specified nicknames", %{
      conn: conn,
      admin: admin,
      user1: user1,
      user2: user2
    } do
      assert empty_json_response(conn)
      assert User.get_cached_by_id(user1.id).tags == ["x", "foo", "bar"]
      assert User.get_cached_by_id(user2.id).tags == ["y", "foo", "bar"]

      log_entry = Repo.one(ModerationLog)

      users =
        [user1.nickname, user2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["foo", "bar"] |> Enum.join(", ")

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} added tags: #{tags} to users: #{users}"
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert empty_json_response(conn)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "DELETE /api/pleroma/admin/users/tag" do
    setup %{conn: conn} do
      user1 = insert(:user, %{tags: ["x"]})
      user2 = insert(:user, %{tags: ["y", "z"]})
      user3 = insert(:user, %{tags: ["unchanged"]})

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete(
          "/api/pleroma/admin/users/tag?nicknames[]=#{user1.nickname}&nicknames[]=" <>
            "#{user2.nickname}&tags[]=x&tags[]=z"
        )

      %{conn: conn, user1: user1, user2: user2, user3: user3}
    end

    test "it removes specified tags from users with specified nicknames", %{
      conn: conn,
      admin: admin,
      user1: user1,
      user2: user2
    } do
      assert empty_json_response(conn)
      assert User.get_cached_by_id(user1.id).tags == []
      assert User.get_cached_by_id(user2.id).tags == ["y"]

      log_entry = Repo.one(ModerationLog)

      users =
        [user1.nickname, user2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["x", "z"] |> Enum.join(", ")

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} removed tags: #{tags} from users: #{users}"
    end

    test "it does not modify tags of not specified users", %{conn: conn, user3: user3} do
      assert empty_json_response(conn)
      assert User.get_cached_by_id(user3.id).tags == ["unchanged"]
    end
  end

  describe "/api/pleroma/admin/users/:nickname/permission_group" do
    test "GET is giving user_info", %{admin: admin, conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/pleroma/admin/users/#{admin.nickname}/permission_group/")

      assert json_response(conn, 200) == %{
               "is_admin" => true,
               "is_moderator" => false
             }
    end

    test "/:right POST, can add to a permission group", %{admin: admin, conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{
               "is_admin" => true
             }

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user.nickname} admin"
    end

    test "/:right POST, can add to a permission group (multiple)", %{admin: admin, conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{"is_admin" => true}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{user_one.nickname}, @#{user_two.nickname} admin"
    end

    test "/:right DELETE, can remove from a permission group", %{admin: admin, conn: conn} do
      user = insert(:user, is_admin: true)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/#{user.nickname}/permission_group/admin")

      assert json_response(conn, 200) == %{"is_admin" => false}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user.nickname}"
    end

    test "/:right DELETE, can remove from a permission group (multiple)", %{
      admin: admin,
      conn: conn
    } do
      user_one = insert(:user, is_admin: true)
      user_two = insert(:user, is_admin: true)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users/permission_group/admin", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      assert json_response(conn, 200) == %{"is_admin" => false}

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} revoked admin role from @#{user_one.nickname}, @#{user_two.nickname}"
    end
  end

  test "/api/pleroma/admin/users/:nickname/password_reset", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/pleroma/admin/users/#{user.nickname}/password_reset")

    resp = json_response(conn, 200)

    assert Regex.match?(~r/(http:\/\/|https:\/\/)/, resp["link"])
  end

  describe "PUT disable_mfa" do
    test "returns 200 and disable 2fa", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            totp: %MFA.Settings.TOTP{secret: "otp_secret", confirmed: true}
          }
        )

      response =
        conn
        |> put("/api/pleroma/admin/users/disable_mfa", %{nickname: user.nickname})
        |> json_response(200)

      assert response == user.nickname
      mfa_settings = refresh_record(user).multi_factor_authentication_settings

      refute mfa_settings.enabled
      refute mfa_settings.totp.confirmed
    end

    test "returns 404 if user not found", %{conn: conn} do
      response =
        conn
        |> put("/api/pleroma/admin/users/disable_mfa", %{nickname: "nickname"})
        |> json_response(404)

      assert response == %{"error" => "Not found"}
    end
  end

  describe "GET /api/pleroma/admin/restart" do
    setup do: clear_config(:configurable_from_database, true)

    test "pleroma restarts", %{conn: conn} do
      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) == %{}
      end) =~ "pleroma restarted"

      refute Restarter.Pleroma.need_reboot?()
    end
  end

  test "need_reboot flag", %{conn: conn} do
    assert conn
           |> get("/api/pleroma/admin/need_reboot")
           |> json_response(200) == %{"need_reboot" => false}

    Restarter.Pleroma.need_reboot()

    assert conn
           |> get("/api/pleroma/admin/need_reboot")
           |> json_response(200) == %{"need_reboot" => true}

    on_exit(fn -> Restarter.Pleroma.refresh() end)
  end

  describe "GET /api/pleroma/admin/users/:nickname/statuses" do
    setup do
      user = insert(:user)

      insert(:note_activity, user: user)
      insert(:note_activity, user: user)
      insert(:note_activity, user: user)

      %{user: user}
    end

    test "renders user's statuses", %{conn: conn, user: user} do
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/statuses")

      assert %{"total" => 3, "activities" => activities} = json_response(conn, 200)
      assert length(activities) == 3
    end

    test "renders user's statuses with pagination", %{conn: conn, user: user} do
      %{"total" => 3, "activities" => [activity1]} =
        conn
        |> get("/api/pleroma/admin/users/#{user.nickname}/statuses?page_size=1&page=1")
        |> json_response(200)

      %{"total" => 3, "activities" => [activity2]} =
        conn
        |> get("/api/pleroma/admin/users/#{user.nickname}/statuses?page_size=1&page=2")
        |> json_response(200)

      refute activity1 == activity2
    end

    test "doesn't return private statuses by default", %{conn: conn, user: user} do
      {:ok, _private_status} = CommonAPI.post(user, %{status: "private", visibility: "private"})

      {:ok, _public_status} = CommonAPI.post(user, %{status: "public", visibility: "public"})

      %{"total" => 4, "activities" => activities} =
        conn
        |> get("/api/pleroma/admin/users/#{user.nickname}/statuses")
        |> json_response(200)

      assert length(activities) == 4
    end

    test "returns private statuses with godmode on", %{conn: conn, user: user} do
      {:ok, _private_status} = CommonAPI.post(user, %{status: "private", visibility: "private"})

      {:ok, _public_status} = CommonAPI.post(user, %{status: "public", visibility: "public"})

      %{"total" => 5, "activities" => activities} =
        conn
        |> get("/api/pleroma/admin/users/#{user.nickname}/statuses?godmode=true")
        |> json_response(200)

      assert length(activities) == 5
    end

    test "excludes reblogs by default", %{conn: conn, user: user} do
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "."})
      {:ok, %Activity{}} = CommonAPI.repeat(activity.id, other_user)

      assert %{"total" => 0, "activities" => []} ==
               conn
               |> get("/api/pleroma/admin/users/#{other_user.nickname}/statuses")
               |> json_response(200)

      assert %{"total" => 1, "activities" => [_]} =
               conn
               |> get(
                 "/api/pleroma/admin/users/#{other_user.nickname}/statuses?with_reblogs=true"
               )
               |> json_response(200)
    end
  end

  describe "GET /api/pleroma/admin/users/:nickname/chats" do
    setup do
      user = insert(:user)
      recipients = insert_list(3, :user)

      Enum.each(recipients, fn recipient ->
        CommonAPI.post_chat_message(user, recipient, "yo")
      end)

      %{user: user}
    end

    test "renders user's chats", %{conn: conn, user: user} do
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/chats")

      assert json_response(conn, 200) |> length() == 3
    end
  end

  describe "GET /api/pleroma/admin/users/:nickname/chats unauthorized" do
    setup do
      user = insert(:user)
      recipient = insert(:user)
      CommonAPI.post_chat_message(user, recipient, "yo")
      %{conn: conn} = oauth_access(["read:chats"])
      %{conn: conn, user: user}
    end

    test "returns 403", %{conn: conn, user: user} do
      conn
      |> get("/api/pleroma/admin/users/#{user.nickname}/chats")
      |> json_response(403)
    end
  end

  describe "GET /api/pleroma/admin/users/:nickname/chats unauthenticated" do
    setup do
      user = insert(:user)
      recipient = insert(:user)
      CommonAPI.post_chat_message(user, recipient, "yo")
      %{conn: build_conn(), user: user}
    end

    test "returns 403", %{conn: conn, user: user} do
      conn
      |> get("/api/pleroma/admin/users/#{user.nickname}/chats")
      |> json_response(403)
    end
  end

  describe "GET /api/pleroma/admin/moderation_log" do
    setup do
      moderator = insert(:user, is_moderator: true)

      %{moderator: moderator}
    end

    test "returns the log", %{conn: conn, admin: admin} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-15 15:47:06.597036], :second)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-16 15:47:06.597036], :second)
      })

      conn = get(conn, "/api/pleroma/admin/moderation_log")

      response = json_response(conn, 200)
      [first_entry, second_entry] = response["items"]

      assert response["total"] == 2
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"

      assert second_entry["data"]["action"] == "relay_follow"

      assert second_entry["message"] ==
               "@#{admin.nickname} followed relay: https://example.org/relay"
    end

    test "returns the log with pagination", %{conn: conn, admin: admin} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-15 15:47:06.597036], :second)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.truncate(~N[2017-08-16 15:47:06.597036], :second)
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?page_size=1&page=1")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 2
      assert response1["items"] |> length() == 1
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"

      conn2 = get(conn, "/api/pleroma/admin/moderation_log?page_size=1&page=2")

      response2 = json_response(conn2, 200)
      [second_entry] = response2["items"]

      assert response2["total"] == 2
      assert response2["items"] |> length() == 1
      assert second_entry["data"]["action"] == "relay_follow"

      assert second_entry["message"] ==
               "@#{admin.nickname} followed relay: https://example.org/relay"
    end

    test "filters log by date", %{conn: conn, admin: admin} do
      first_date = "2017-08-15T15:47:06Z"
      second_date = "2017-08-20T15:47:06Z"

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.from_iso8601!(first_date)
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        },
        inserted_at: NaiveDateTime.from_iso8601!(second_date)
      })

      conn1 =
        get(
          conn,
          "/api/pleroma/admin/moderation_log?start_date=#{second_date}"
        )

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1
      assert first_entry["data"]["action"] == "relay_unfollow"

      assert first_entry["message"] ==
               "@#{admin.nickname} unfollowed relay: https://example.org/relay"
    end

    test "returns log filtered by user", %{conn: conn, admin: admin, moderator: moderator} do
      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => admin.id,
            "nickname" => admin.nickname,
            "type" => "user"
          },
          action: "relay_follow",
          target: "https://example.org/relay"
        }
      })

      Repo.insert(%ModerationLog{
        data: %{
          actor: %{
            "id" => moderator.id,
            "nickname" => moderator.nickname,
            "type" => "user"
          },
          action: "relay_unfollow",
          target: "https://example.org/relay"
        }
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?user_id=#{moderator.id}")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1
      assert get_in(first_entry, ["data", "actor", "id"]) == moderator.id
    end

    test "returns log filtered by search", %{conn: conn, moderator: moderator} do
      ModerationLog.insert_log(%{
        actor: moderator,
        action: "relay_follow",
        target: "https://example.org/relay"
      })

      ModerationLog.insert_log(%{
        actor: moderator,
        action: "relay_unfollow",
        target: "https://example.org/relay"
      })

      conn1 = get(conn, "/api/pleroma/admin/moderation_log?search=unfo")

      response1 = json_response(conn1, 200)
      [first_entry] = response1["items"]

      assert response1["total"] == 1

      assert get_in(first_entry, ["data", "message"]) ==
               "@#{moderator.nickname} unfollowed relay: https://example.org/relay"
    end
  end

  test "gets a remote users when [:instance, :limit_to_local_content] is set to :unauthenticated",
       %{conn: conn} do
    clear_config(Pleroma.Config.get([:instance, :limit_to_local_content]), :unauthenticated)
    user = insert(:user, %{local: false, nickname: "u@peer1.com"})
    conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials")

    assert json_response(conn, 200)
  end

  describe "GET /users/:nickname/credentials" do
    test "gets the user credentials", %{conn: conn} do
      user = insert(:user)
      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials")

      response = assert json_response(conn, 200)
      assert response["email"] == user.email
    end

    test "returns 403 if requested by a non-admin" do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/pleroma/admin/users/#{user.nickname}/credentials")

      assert json_response(conn, :forbidden)
    end
  end

  describe "PATCH /users/:nickname/credentials" do
    setup do
      user = insert(:user)
      [user: user]
    end

    test "changes password and email", %{conn: conn, admin: admin, user: user} do
      assert user.password_reset_pending == false

      conn =
        patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
          "password" => "new_password",
          "email" => "new_email@example.com",
          "name" => "new_name"
        })

      assert json_response(conn, 200) == %{"status" => "success"}

      ObanHelpers.perform_all()

      updated_user = User.get_by_id(user.id)

      assert updated_user.email == "new_email@example.com"
      assert updated_user.name == "new_name"
      assert updated_user.password_hash != user.password_hash
      assert updated_user.password_reset_pending == true

      [log_entry2, log_entry1] = ModerationLog |> Repo.all() |> Enum.sort()

      assert ModerationLog.get_log_entry_message(log_entry1) ==
               "@#{admin.nickname} updated users: @#{user.nickname}"

      assert ModerationLog.get_log_entry_message(log_entry2) ==
               "@#{admin.nickname} forced password reset for users: @#{user.nickname}"
    end

    test "returns 403 if requested by a non-admin", %{user: user} do
      conn =
        build_conn()
        |> assign(:user, user)
        |> patch("/api/pleroma/admin/users/#{user.nickname}/credentials", %{
          "password" => "new_password",
          "email" => "new_email@example.com",
          "name" => "new_name"
        })

      assert json_response(conn, :forbidden)
    end

    test "changes actor type from permitted list", %{conn: conn, user: user} do
      assert user.actor_type == "Person"

      assert patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
               "actor_type" => "Service"
             })
             |> json_response(200) == %{"status" => "success"}

      updated_user = User.get_by_id(user.id)

      assert updated_user.actor_type == "Service"

      assert patch(conn, "/api/pleroma/admin/users/#{user.nickname}/credentials", %{
               "actor_type" => "Application"
             })
             |> json_response(400) == %{"errors" => %{"actor_type" => "is invalid"}}
    end

    test "update non existing user", %{conn: conn} do
      assert patch(conn, "/api/pleroma/admin/users/non-existing/credentials", %{
               "password" => "new_password"
             })
             |> json_response(404) == %{"error" => "Not found"}
    end
  end

  describe "PATCH /users/:nickname/force_password_reset" do
    test "sets password_reset_pending to true", %{conn: conn} do
      user = insert(:user)
      assert user.password_reset_pending == false

      conn =
        patch(conn, "/api/pleroma/admin/users/force_password_reset", %{nicknames: [user.nickname]})

      assert empty_json_response(conn) == ""

      ObanHelpers.perform_all()

      assert User.get_by_id(user.id).password_reset_pending == true
    end
  end

  describe "PATCH /confirm_email" do
    test "it confirms emails of two users", %{conn: conn, admin: admin} do
      [first_user, second_user] = insert_pair(:user, is_confirmed: false)

      refute first_user.is_confirmed
      refute second_user.is_confirmed

      ret_conn =
        patch(conn, "/api/pleroma/admin/users/confirm_email", %{
          nicknames: [
            first_user.nickname,
            second_user.nickname
          ]
        })

      assert ret_conn.status == 200

      first_user = User.get_by_id(first_user.id)
      second_user = User.get_by_id(second_user.id)

      assert first_user.is_confirmed
      assert second_user.is_confirmed

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} confirmed email for users: @#{first_user.nickname}, @#{second_user.nickname}"
    end
  end

  describe "PATCH /resend_confirmation_email" do
    test "it resend emails for two users", %{conn: conn, admin: admin} do
      [first_user, second_user] = insert_pair(:user, is_confirmed: false)

      ret_conn =
        patch(conn, "/api/pleroma/admin/users/resend_confirmation_email", %{
          nicknames: [
            first_user.nickname,
            second_user.nickname
          ]
        })

      assert ret_conn.status == 200

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} re-sent confirmation email for users: @#{first_user.nickname}, @#{second_user.nickname}"

      ObanHelpers.perform_all()

      Pleroma.Emails.UserEmail.account_confirmation_email(first_user)
      # temporary hackney fix until hackney max_connections bug is fixed
      # https://git.pleroma.social/pleroma/pleroma/-/issues/2101
      |> Swoosh.Email.put_private(:hackney_options, ssl_options: [versions: [:"tlsv1.2"]])
      |> assert_email_sent()
    end
  end

  describe "/api/pleroma/admin/stats" do
    test "status visibility count", %{conn: conn} do
      user = insert(:user)
      CommonAPI.post(user, %{visibility: "public", status: "hey"})
      CommonAPI.post(user, %{visibility: "unlisted", status: "hey"})
      CommonAPI.post(user, %{visibility: "unlisted", status: "hey"})

      response =
        conn
        |> get("/api/pleroma/admin/stats")
        |> json_response(200)

      assert %{"direct" => 0, "private" => 0, "public" => 1, "unlisted" => 2} =
               response["status_visibility"]
    end

    test "by instance", %{conn: conn} do
      user1 = insert(:user)
      instance2 = "instance2.tld"
      user2 = insert(:user, %{ap_id: "https://#{instance2}/@actor"})

      CommonAPI.post(user1, %{visibility: "public", status: "hey"})
      CommonAPI.post(user2, %{visibility: "unlisted", status: "hey"})
      CommonAPI.post(user2, %{visibility: "private", status: "hey"})

      response =
        conn
        |> get("/api/pleroma/admin/stats", instance: instance2)
        |> json_response(200)

      assert %{"direct" => 0, "private" => 1, "public" => 0, "unlisted" => 1} =
               response["status_visibility"]
    end
  end

  describe "/api/pleroma/backups" do
    test "it creates a backup", %{conn: conn} do
      admin = %{id: admin_id, nickname: admin_nickname} = insert(:user, is_admin: true)
      token = insert(:oauth_admin_token, user: admin)
      user = %{id: user_id, nickname: user_nickname} = insert(:user)

      assert "" ==
               conn
               |> assign(:user, admin)
               |> assign(:token, token)
               |> post("/api/pleroma/admin/backups", %{nickname: user.nickname})
               |> json_response(200)

      assert [backup] = Repo.all(Pleroma.User.Backup)

      ObanHelpers.perform_all()

      email = Pleroma.Emails.UserEmail.backup_is_ready_email(backup, admin.id)

      assert String.contains?(email.html_body, "Admin @#{admin.nickname} requested a full backup")
      assert_email_sent(to: {user.name, user.email}, html_body: email.html_body)

      log_message = "@#{admin_nickname} requested account backup for @#{user_nickname}"

      assert [
               %{
                 data: %{
                   "action" => "create_backup",
                   "actor" => %{
                     "id" => ^admin_id,
                     "nickname" => ^admin_nickname
                   },
                   "message" => ^log_message,
                   "subject" => %{
                     "id" => ^user_id,
                     "nickname" => ^user_nickname
                   }
                 }
               }
             ] = Pleroma.ModerationLog |> Repo.all()
    end

    test "it doesn't limit admins", %{conn: conn} do
      admin = insert(:user, is_admin: true)
      token = insert(:oauth_admin_token, user: admin)
      user = insert(:user)

      assert "" ==
               conn
               |> assign(:user, admin)
               |> assign(:token, token)
               |> post("/api/pleroma/admin/backups", %{nickname: user.nickname})
               |> json_response(200)

      assert [_backup] = Repo.all(Pleroma.User.Backup)

      assert "" ==
               conn
               |> assign(:user, admin)
               |> assign(:token, token)
               |> post("/api/pleroma/admin/backups", %{nickname: user.nickname})
               |> json_response(200)

      assert Repo.aggregate(Pleroma.User.Backup, :count) == 2
    end
  end
end

# Needed for testing
defmodule Pleroma.Web.Endpoint.NotReal do
end

defmodule Pleroma.Captcha.NotReal do
end
