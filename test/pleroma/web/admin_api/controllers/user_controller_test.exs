# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.UserControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mock
  import Pleroma.Factory

  alias Pleroma.HTML
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MediaProxy

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

  describe "with [:auth, :enforce_oauth_admin_scope_usage]," do
    setup do: clear_config([:auth, :enforce_oauth_admin_scope_usage], true)

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
  end

  describe "unless [:auth, :enforce_oauth_admin_scope_usage]," do
    setup do: clear_config([:auth, :enforce_oauth_admin_scope_usage], false)

    test "GET /api/pleroma/admin/users/:nickname requires " <>
           "read:accounts or admin:read:accounts or broader scope",
         %{admin: admin} do
      user = insert(:user)
      url = "/api/pleroma/admin/users/#{user.nickname}"

      good_token1 = insert(:oauth_token, user: admin, scopes: ["admin"])
      good_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read"])
      good_token3 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts"])
      good_token4 = insert(:oauth_token, user: admin, scopes: ["read:accounts"])
      good_token5 = insert(:oauth_token, user: admin, scopes: ["read"])

      good_tokens = [good_token1, good_token2, good_token3, good_token4, good_token5]

      bad_token1 = insert(:oauth_token, user: admin, scopes: ["read:accounts:partial"])
      bad_token2 = insert(:oauth_token, user: admin, scopes: ["admin:read:accounts:partial"])
      bad_token3 = nil

      for good_token <- good_tokens do
        conn =
          build_conn()
          |> assign(:user, admin)
          |> assign(:token, good_token)
          |> get(url)

        assert json_response(conn, 200)
      end

      for good_token <- good_tokens do
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
  end

  describe "DELETE /api/pleroma/admin/users" do
    test "single user", %{admin: admin, conn: conn} do
      clear_config([:instance, :federating], true)

      user =
        insert(:user,
          avatar: %{"url" => [%{"href" => "https://someurl"}]},
          banner: %{"url" => [%{"href" => "https://somebanner"}]},
          bio: "Hello world!",
          name: "A guy"
        )

      # Create some activities to check they got deleted later
      follower = insert(:user)
      {:ok, _} = CommonAPI.post(user, %{status: "test"})
      {:ok, _, _, _} = CommonAPI.follow(user, follower)
      {:ok, _, _, _} = CommonAPI.follow(follower, user)
      user = Repo.get(User, user.id)
      assert user.note_count == 1
      assert user.follower_count == 1
      assert user.following_count == 1
      assert user.is_active

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end,
        perform: fn _, _ -> nil end do
        conn =
          conn
          |> put_req_header("accept", "application/json")
          |> delete("/api/pleroma/admin/users?nickname=#{user.nickname}")

        ObanHelpers.perform_all()

        refute User.get_by_nickname(user.nickname).is_active

        log_entry = Repo.one(ModerationLog)

        assert ModerationLog.get_log_entry_message(log_entry) ==
                 "@#{admin.nickname} deleted users: @#{user.nickname}"

        assert json_response(conn, 200) == [user.nickname]

        user = Repo.get(User, user.id)
        refute user.is_active

        assert user.avatar == %{}
        assert user.banner == %{}
        assert user.note_count == 0
        assert user.follower_count == 0
        assert user.following_count == 0
        assert user.bio == ""
        assert user.name == nil

        assert called(Pleroma.Web.Federator.publish(:_))
      end
    end

    test "multiple users", %{admin: admin, conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> delete("/api/pleroma/admin/users", %{
          nicknames: [user_one.nickname, user_two.nickname]
        })

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted users: @#{user_one.nickname}, @#{user_two.nickname}"

      response = json_response(conn, 200)
      assert response -- [user_one.nickname, user_two.nickname] == []
    end
  end

  describe "/api/pleroma/admin/users" do
    test "Create", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "lain",
              "email" => "lain@example.org",
              "password" => "test"
            },
            %{
              "nickname" => "lain2",
              "email" => "lain2@example.org",
              "password" => "test"
            }
          ]
        })

      response = json_response(conn, 200) |> Enum.map(&Map.get(&1, "type"))
      assert response == ["success", "success"]

      log_entry = Repo.one(ModerationLog)

      assert ["lain", "lain2"] -- Enum.map(log_entry.data["subjects"], & &1["nickname"]) == []
    end

    test "Cannot create user with existing email", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "lain",
              "email" => user.email,
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => user.email,
                   "nickname" => "lain"
                 },
                 "error" => "email has already been taken",
                 "type" => "error"
               }
             ]
    end

    test "Cannot create user with existing nickname", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => user.nickname,
              "email" => "someuser@plerama.social",
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => "someuser@plerama.social",
                   "nickname" => user.nickname
                 },
                 "error" => "nickname has already been taken",
                 "type" => "error"
               }
             ]
    end

    test "Multiple user creation works in transaction", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/api/pleroma/admin/users", %{
          "users" => [
            %{
              "nickname" => "newuser",
              "email" => "newuser@pleroma.social",
              "password" => "test"
            },
            %{
              "nickname" => "lain",
              "email" => user.email,
              "password" => "test"
            }
          ]
        })

      assert json_response(conn, 409) == [
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => user.email,
                   "nickname" => "lain"
                 },
                 "error" => "email has already been taken",
                 "type" => "error"
               },
               %{
                 "code" => 409,
                 "data" => %{
                   "email" => "newuser@pleroma.social",
                   "nickname" => "newuser"
                 },
                 "error" => "",
                 "type" => "error"
               }
             ]

      assert User.get_by_nickname("newuser") === nil
    end
  end

  describe "/api/pleroma/admin/users/:nickname" do
    test "Show", %{conn: conn} do
      user = insert(:user)

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}")

      assert user_response(user) == json_response(conn, 200)
    end

    test "when the user doesn't exist", %{conn: conn} do
      user = build(:user)

      conn = get(conn, "/api/pleroma/admin/users/#{user.nickname}")

      assert %{"error" => "Not found"} == json_response(conn, 404)
    end
  end

  describe "/api/pleroma/admin/users/follow" do
    test "allows to force-follow another user", %{admin: admin, conn: conn} do
      user = insert(:user)
      follower = insert(:user)

      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/pleroma/admin/users/follow", %{
        "follower" => follower.nickname,
        "followed" => user.nickname
      })

      user = User.get_cached_by_id(user.id)
      follower = User.get_cached_by_id(follower.id)

      assert User.following?(follower, user)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{follower.nickname} follow @#{user.nickname}"
    end
  end

  describe "/api/pleroma/admin/users/unfollow" do
    test "allows to force-unfollow another user", %{admin: admin, conn: conn} do
      user = insert(:user)
      follower = insert(:user)

      User.follow(follower, user)

      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/pleroma/admin/users/unfollow", %{
        "follower" => follower.nickname,
        "followed" => user.nickname
      })

      user = User.get_cached_by_id(user.id)
      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, user)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} made @#{follower.nickname} unfollow @#{user.nickname}"
    end
  end

  describe "GET /api/pleroma/admin/users" do
    test "renders users array for the first page", %{conn: conn, admin: admin} do
      user = insert(:user, local: false, tags: ["foo", "bar"])
      user2 = insert(:user, is_approved: false, registration_reason: "I'm a chill dude")

      conn = get(conn, "/api/pleroma/admin/users?page=1")

      users =
        [
          user_response(
            admin,
            %{"roles" => %{"admin" => true, "moderator" => false}}
          ),
          user_response(user, %{"local" => false, "tags" => ["foo", "bar"]}),
          user_response(
            user2,
            %{
              "local" => true,
              "is_approved" => false,
              "registration_reason" => "I'm a chill dude",
              "actor_type" => "Person"
            }
          )
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 3,
               "page_size" => 50,
               "users" => users
             }
    end

    test "pagination works correctly with service users", %{conn: conn} do
      service1 = User.get_or_create_service_actor_by_ap_id(Web.base_url() <> "/meido", "meido")

      insert_list(25, :user)

      assert %{"count" => 26, "page_size" => 10, "users" => users1} =
               conn
               |> get("/api/pleroma/admin/users?page=1&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users1) == 10
      assert service1 not in users1

      assert %{"count" => 26, "page_size" => 10, "users" => users2} =
               conn
               |> get("/api/pleroma/admin/users?page=2&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users2) == 10
      assert service1 not in users2

      assert %{"count" => 26, "page_size" => 10, "users" => users3} =
               conn
               |> get("/api/pleroma/admin/users?page=3&filters=", %{page_size: "10"})
               |> json_response(200)

      assert Enum.count(users3) == 6
      assert service1 not in users3
    end

    test "renders empty array for the second page", %{conn: conn} do
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?page=2")

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => []
             }
    end

    test "regular search", %{conn: conn} do
      user = insert(:user, nickname: "bob")

      conn = get(conn, "/api/pleroma/admin/users?query=bo")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user, %{"local" => true})]
             }
    end

    test "search by domain", %{conn: conn} do
      user = insert(:user, nickname: "nickname@domain.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?query=domain.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "search by full nickname", %{conn: conn} do
      user = insert(:user, nickname: "nickname@domain.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?query=nickname@domain.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "search by display name", %{conn: conn} do
      user = insert(:user, name: "Display name")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?name=display")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "search by email", %{conn: conn} do
      user = insert(:user, email: "email@example.com")
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?email=email@example.com")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "regular search with page size", %{conn: conn} do
      user = insert(:user, nickname: "aalice")
      user2 = insert(:user, nickname: "alice")

      conn1 = get(conn, "/api/pleroma/admin/users?query=a&page_size=1&page=1")

      assert json_response(conn1, 200) == %{
               "count" => 2,
               "page_size" => 1,
               "users" => [user_response(user)]
             }

      conn2 = get(conn, "/api/pleroma/admin/users?query=a&page_size=1&page=2")

      assert json_response(conn2, 200) == %{
               "count" => 2,
               "page_size" => 1,
               "users" => [user_response(user2)]
             }
    end

    test "only local users" do
      admin = insert(:user, is_admin: true, nickname: "john")
      token = insert(:oauth_admin_token, user: admin)
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/users?query=bo&filters=local")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "only local users with no query", %{conn: conn, admin: old_admin} do
      admin = insert(:user, is_admin: true, nickname: "john")
      user = insert(:user, nickname: "bob")

      insert(:user, nickname: "bobb", local: false)

      conn = get(conn, "/api/pleroma/admin/users?filters=local")

      users =
        [
          user_response(user),
          user_response(admin, %{
            "roles" => %{"admin" => true, "moderator" => false}
          }),
          user_response(old_admin, %{
            "is_active" => true,
            "roles" => %{"admin" => true, "moderator" => false}
          })
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 3,
               "page_size" => 50,
               "users" => users
             }
    end

    test "only unconfirmed users", %{conn: conn} do
      sad_user = insert(:user, nickname: "sadboy", is_confirmed: false)
      old_user = insert(:user, nickname: "oldboy", is_confirmed: false)

      insert(:user, nickname: "happyboy", is_approved: true)
      insert(:user, is_confirmed: true)

      result =
        conn
        |> get("/api/pleroma/admin/users?filters=unconfirmed")
        |> json_response(200)

      users =
        Enum.map([old_user, sad_user], fn user ->
          user_response(user, %{
            "is_confirmed" => false,
            "is_approved" => true
          })
        end)
        |> Enum.sort_by(& &1["nickname"])

      assert result == %{"count" => 2, "page_size" => 50, "users" => users}
    end

    test "only unapproved users", %{conn: conn} do
      user =
        insert(:user,
          nickname: "sadboy",
          is_approved: false,
          registration_reason: "Plz let me in!"
        )

      insert(:user, nickname: "happyboy", is_approved: true)

      conn = get(conn, "/api/pleroma/admin/users?filters=need_approval")

      users = [
        user_response(
          user,
          %{"is_approved" => false, "registration_reason" => "Plz let me in!"}
        )
      ]

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => users
             }
    end

    test "load only admins", %{conn: conn, admin: admin} do
      second_admin = insert(:user, is_admin: true)
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?filters=is_admin")

      users =
        [
          user_response(admin, %{
            "is_active" => true,
            "roles" => %{"admin" => true, "moderator" => false}
          }),
          user_response(second_admin, %{
            "is_active" => true,
            "roles" => %{"admin" => true, "moderator" => false}
          })
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => users
             }
    end

    test "load only moderators", %{conn: conn} do
      moderator = insert(:user, is_moderator: true)
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?filters=is_moderator")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 user_response(moderator, %{
                   "is_active" => true,
                   "roles" => %{"admin" => false, "moderator" => true}
                 })
               ]
             }
    end

    test "load users with actor_type is Person", %{admin: admin, conn: conn} do
      insert(:user, actor_type: "Service")
      insert(:user, actor_type: "Application")

      user1 = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> get(user_path(conn, :list), %{actor_types: ["Person"]})
        |> json_response(200)

      users =
        [
          user_response(admin, %{"roles" => %{"admin" => true, "moderator" => false}}),
          user_response(user1),
          user_response(user2)
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert response == %{"count" => 3, "page_size" => 50, "users" => users}
    end

    test "load users with actor_type is Person and Service", %{admin: admin, conn: conn} do
      user_service = insert(:user, actor_type: "Service")
      insert(:user, actor_type: "Application")

      user1 = insert(:user)
      user2 = insert(:user)

      response =
        conn
        |> get(user_path(conn, :list), %{actor_types: ["Person", "Service"]})
        |> json_response(200)

      users =
        [
          user_response(admin, %{"roles" => %{"admin" => true, "moderator" => false}}),
          user_response(user1),
          user_response(user2),
          user_response(user_service, %{"actor_type" => "Service"})
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert response == %{"count" => 4, "page_size" => 50, "users" => users}
    end

    test "load users with actor_type is Service", %{conn: conn} do
      user_service = insert(:user, actor_type: "Service")
      insert(:user, actor_type: "Application")
      insert(:user)
      insert(:user)

      response =
        conn
        |> get(user_path(conn, :list), %{actor_types: ["Service"]})
        |> json_response(200)

      users = [user_response(user_service, %{"actor_type" => "Service"})]

      assert response == %{"count" => 1, "page_size" => 50, "users" => users}
    end

    test "load users with tags list", %{conn: conn} do
      user1 = insert(:user, tags: ["first"])
      user2 = insert(:user, tags: ["second"])
      insert(:user)
      insert(:user)

      conn = get(conn, "/api/pleroma/admin/users?tags[]=first&tags[]=second")

      users =
        [
          user_response(user1, %{"tags" => ["first"]}),
          user_response(user2, %{"tags" => ["second"]})
        ]
        |> Enum.sort_by(& &1["nickname"])

      assert json_response(conn, 200) == %{
               "count" => 2,
               "page_size" => 50,
               "users" => users
             }
    end

    test "`active` filters out users pending approval", %{token: token} do
      insert(:user, is_approved: false)
      %{id: user_id} = insert(:user, is_approved: true)
      %{id: admin_id} = token.user

      conn =
        build_conn()
        |> assign(:user, token.user)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/users?filters=active")

      assert %{
               "count" => 2,
               "page_size" => 50,
               "users" => [
                 %{"id" => ^admin_id},
                 %{"id" => ^user_id}
               ]
             } = json_response(conn, 200)
    end

    test "it works with multiple filters" do
      admin = insert(:user, nickname: "john", is_admin: true)
      token = insert(:oauth_admin_token, user: admin)
      user = insert(:user, nickname: "bob", local: false, is_active: false)

      insert(:user, nickname: "ken", local: true, is_active: false)
      insert(:user, nickname: "bobb", local: false, is_active: true)

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> get("/api/pleroma/admin/users?filters=deactivated,external")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [user_response(user)]
             }
    end

    test "it omits relay user", %{admin: admin, conn: conn} do
      assert %User{} = Relay.get_actor()

      conn = get(conn, "/api/pleroma/admin/users")

      assert json_response(conn, 200) == %{
               "count" => 1,
               "page_size" => 50,
               "users" => [
                 user_response(admin, %{"roles" => %{"admin" => true, "moderator" => false}})
               ]
             }
    end
  end

  test "PATCH /api/pleroma/admin/users/activate", %{admin: admin, conn: conn} do
    user_one = insert(:user, is_active: false)
    user_two = insert(:user, is_active: false)

    conn =
      patch(
        conn,
        "/api/pleroma/admin/users/activate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["is_active"]) == [true, true]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} activated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/deactivate", %{admin: admin, conn: conn} do
    user_one = insert(:user, is_active: true)
    user_two = insert(:user, is_active: true)

    conn =
      patch(
        conn,
        "/api/pleroma/admin/users/deactivate",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["is_active"]) == [false, false]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} deactivated users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/approve", %{admin: admin, conn: conn} do
    user_one = insert(:user, is_approved: false)
    user_two = insert(:user, is_approved: false)

    conn =
      patch(
        conn,
        "/api/pleroma/admin/users/approve",
        %{nicknames: [user_one.nickname, user_two.nickname]}
      )

    response = json_response(conn, 200)
    assert Enum.map(response["users"], & &1["is_approved"]) == [true, true]

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} approved users: @#{user_one.nickname}, @#{user_two.nickname}"
  end

  test "PATCH /api/pleroma/admin/users/:nickname/toggle_activation", %{admin: admin, conn: conn} do
    user = insert(:user)

    conn = patch(conn, "/api/pleroma/admin/users/#{user.nickname}/toggle_activation")

    assert json_response(conn, 200) ==
             user_response(
               user,
               %{"is_active" => !user.is_active}
             )

    log_entry = Repo.one(ModerationLog)

    assert ModerationLog.get_log_entry_message(log_entry) ==
             "@#{admin.nickname} deactivated users: @#{user.nickname}"
  end

  defp user_response(user, attrs \\ %{}) do
    %{
      "is_active" => user.is_active,
      "id" => user.id,
      "email" => user.email,
      "nickname" => user.nickname,
      "roles" => %{"admin" => false, "moderator" => false},
      "local" => user.local,
      "tags" => [],
      "avatar" => User.avatar_url(user) |> MediaProxy.url(),
      "display_name" => HTML.strip_tags(user.name || user.nickname),
      "is_confirmed" => true,
      "is_approved" => true,
      "url" => user.ap_id,
      "registration_reason" => nil,
      "actor_type" => "Person"
    }
    |> Map.merge(attrs)
  end
end
