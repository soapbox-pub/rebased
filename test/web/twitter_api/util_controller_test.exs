# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User

  import Pleroma.Factory
  import Mock

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance])
  clear_config([:frontend_configurations, :pleroma_fe])

  describe "POST /api/pleroma/follow_import" do
    setup do: oauth_access(["follow"])

    test "it returns HTTP 200", %{conn: conn} do
      user2 = insert(:user)

      response =
        conn
        |> post("/api/pleroma/follow_import", %{"list" => "#{user2.ap_id}"})
        |> json_response(:ok)

      assert response == "job started"
    end

    test "it imports follow lists from file", %{user: user1, conn: conn} do
      user2 = insert(:user)

      with_mocks([
        {File, [],
         read!: fn "follow_list.txt" ->
           "Account address,Show boosts\n#{user2.ap_id},true"
         end}
      ]) do
        response =
          conn
          |> post("/api/pleroma/follow_import", %{"list" => %Plug.Upload{path: "follow_list.txt"}})
          |> json_response(:ok)

        assert response == "job started"

        assert ObanHelpers.member?(
                 %{
                   "op" => "follow_import",
                   "follower_id" => user1.id,
                   "followed_identifiers" => [user2.ap_id]
                 },
                 all_enqueued(worker: Pleroma.Workers.BackgroundWorker)
               )
      end
    end

    test "it imports new-style mastodon follow lists", %{conn: conn} do
      user2 = insert(:user)

      response =
        conn
        |> post("/api/pleroma/follow_import", %{
          "list" => "Account address,Show boosts\n#{user2.ap_id},true"
        })
        |> json_response(:ok)

      assert response == "job started"
    end

    test "requires 'follow' or 'write:follows' permissions" do
      token1 = insert(:oauth_token, scopes: ["read", "write"])
      token2 = insert(:oauth_token, scopes: ["follow"])
      token3 = insert(:oauth_token, scopes: ["something"])
      another_user = insert(:user)

      for token <- [token1, token2, token3] do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> post("/api/pleroma/follow_import", %{"list" => "#{another_user.ap_id}"})

        if token == token3 do
          assert %{"error" => "Insufficient permissions: follow | write:follows."} ==
                   json_response(conn, 403)
        else
          assert json_response(conn, 200)
        end
      end
    end
  end

  describe "POST /api/pleroma/blocks_import" do
    # Note: "follow" or "write:blocks" permission is required
    setup do: oauth_access(["write:blocks"])

    test "it returns HTTP 200", %{conn: conn} do
      user2 = insert(:user)

      response =
        conn
        |> post("/api/pleroma/blocks_import", %{"list" => "#{user2.ap_id}"})
        |> json_response(:ok)

      assert response == "job started"
    end

    test "it imports blocks users from file", %{user: user1, conn: conn} do
      user2 = insert(:user)
      user3 = insert(:user)

      with_mocks([
        {File, [], read!: fn "blocks_list.txt" -> "#{user2.ap_id} #{user3.ap_id}" end}
      ]) do
        response =
          conn
          |> post("/api/pleroma/blocks_import", %{"list" => %Plug.Upload{path: "blocks_list.txt"}})
          |> json_response(:ok)

        assert response == "job started"

        assert ObanHelpers.member?(
                 %{
                   "op" => "blocks_import",
                   "blocker_id" => user1.id,
                   "blocked_identifiers" => [user2.ap_id, user3.ap_id]
                 },
                 all_enqueued(worker: Pleroma.Workers.BackgroundWorker)
               )
      end
    end
  end

  describe "PUT /api/pleroma/notification_settings" do
    setup do: oauth_access(["write:accounts"])

    test "it updates notification settings", %{user: user, conn: conn} do
      conn
      |> put("/api/pleroma/notification_settings", %{
        "followers" => false,
        "bar" => 1
      })
      |> json_response(:ok)

      user = refresh_record(user)

      assert %Pleroma.User.NotificationSetting{
               followers: false,
               follows: true,
               non_follows: true,
               non_followers: true,
               privacy_option: false
             } == user.notification_settings
    end

    test "it updates notification privacy option", %{user: user, conn: conn} do
      conn
      |> put("/api/pleroma/notification_settings", %{"privacy_option" => "1"})
      |> json_response(:ok)

      user = refresh_record(user)

      assert %Pleroma.User.NotificationSetting{
               followers: true,
               follows: true,
               non_follows: true,
               non_followers: true,
               privacy_option: true
             } == user.notification_settings
    end
  end

  describe "GET /api/statusnet/config" do
    test "it returns config in xml format", %{conn: conn} do
      instance = Pleroma.Config.get(:instance)

      response =
        conn
        |> put_req_header("accept", "application/xml")
        |> get("/api/statusnet/config")
        |> response(:ok)

      assert response ==
               "<config>\n<site>\n<name>#{Keyword.get(instance, :name)}</name>\n<site>#{
                 Pleroma.Web.base_url()
               }</site>\n<textlimit>#{Keyword.get(instance, :limit)}</textlimit>\n<closed>#{
                 !Keyword.get(instance, :registrations_open)
               }</closed>\n</site>\n</config>\n"
    end

    test "it returns config in json format", %{conn: conn} do
      instance = Pleroma.Config.get(:instance)
      Pleroma.Config.put([:instance, :managed_config], true)
      Pleroma.Config.put([:instance, :registrations_open], false)
      Pleroma.Config.put([:instance, :invites_enabled], true)
      Pleroma.Config.put([:instance, :public], false)
      Pleroma.Config.put([:frontend_configurations, :pleroma_fe], %{theme: "asuka-hospital"})

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/statusnet/config")
        |> json_response(:ok)

      expected_data = %{
        "site" => %{
          "accountActivationRequired" => "0",
          "closed" => "1",
          "description" => Keyword.get(instance, :description),
          "invitesEnabled" => "1",
          "name" => Keyword.get(instance, :name),
          "pleromafe" => %{"theme" => "asuka-hospital"},
          "private" => "1",
          "safeDMMentionsEnabled" => "0",
          "server" => Pleroma.Web.base_url(),
          "textlimit" => to_string(Keyword.get(instance, :limit)),
          "uploadlimit" => %{
            "avatarlimit" => to_string(Keyword.get(instance, :avatar_upload_limit)),
            "backgroundlimit" => to_string(Keyword.get(instance, :background_upload_limit)),
            "bannerlimit" => to_string(Keyword.get(instance, :banner_upload_limit)),
            "uploadlimit" => to_string(Keyword.get(instance, :upload_limit))
          },
          "vapidPublicKey" => Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
        }
      }

      assert response == expected_data
    end

    test "returns the state of safe_dm_mentions flag", %{conn: conn} do
      Pleroma.Config.put([:instance, :safe_dm_mentions], true)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["safeDMMentionsEnabled"] == "1"

      Pleroma.Config.put([:instance, :safe_dm_mentions], false)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["safeDMMentionsEnabled"] == "0"
    end

    test "it returns the managed config", %{conn: conn} do
      Pleroma.Config.put([:instance, :managed_config], false)
      Pleroma.Config.put([:frontend_configurations, :pleroma_fe], %{theme: "asuka-hospital"})

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      refute response["site"]["pleromafe"]

      Pleroma.Config.put([:instance, :managed_config], true)

      response =
        conn
        |> get("/api/statusnet/config.json")
        |> json_response(:ok)

      assert response["site"]["pleromafe"] == %{"theme" => "asuka-hospital"}
    end
  end

  describe "GET /api/pleroma/frontend_configurations" do
    test "returns everything in :pleroma, :frontend_configurations", %{conn: conn} do
      config = [
        frontend_a: %{
          x: 1,
          y: 2
        },
        frontend_b: %{
          z: 3
        }
      ]

      Pleroma.Config.put(:frontend_configurations, config)

      response =
        conn
        |> get("/api/pleroma/frontend_configurations")
        |> json_response(:ok)

      assert response == Jason.encode!(config |> Enum.into(%{})) |> Jason.decode!()
    end
  end

  describe "/api/pleroma/emoji" do
    test "returns json with custom emoji with tags", %{conn: conn} do
      emoji =
        conn
        |> get("/api/pleroma/emoji")
        |> json_response(200)

      assert Enum.all?(emoji, fn
               {_key,
                %{
                  "image_url" => url,
                  "tags" => tags
                }} ->
                 is_binary(url) and is_list(tags)
             end)
    end
  end

  describe "GET /api/pleroma/healthcheck" do
    clear_config([:instance, :healthcheck])

    test "returns 503 when healthcheck disabled", %{conn: conn} do
      Pleroma.Config.put([:instance, :healthcheck], false)

      response =
        conn
        |> get("/api/pleroma/healthcheck")
        |> json_response(503)

      assert response == %{}
    end

    test "returns 200 when healthcheck enabled and all ok", %{conn: conn} do
      Pleroma.Config.put([:instance, :healthcheck], true)

      with_mock Pleroma.Healthcheck,
        system_info: fn -> %Pleroma.Healthcheck{healthy: true} end do
        response =
          conn
          |> get("/api/pleroma/healthcheck")
          |> json_response(200)

        assert %{
                 "active" => _,
                 "healthy" => true,
                 "idle" => _,
                 "memory_used" => _,
                 "pool_size" => _
               } = response
      end
    end

    test "returns 503 when healthcheck enabled and health is false", %{conn: conn} do
      Pleroma.Config.put([:instance, :healthcheck], true)

      with_mock Pleroma.Healthcheck,
        system_info: fn -> %Pleroma.Healthcheck{healthy: false} end do
        response =
          conn
          |> get("/api/pleroma/healthcheck")
          |> json_response(503)

        assert %{
                 "active" => _,
                 "healthy" => false,
                 "idle" => _,
                 "memory_used" => _,
                 "pool_size" => _
               } = response
      end
    end
  end

  describe "POST /api/pleroma/disable_account" do
    setup do: oauth_access(["write:accounts"])

    test "with valid permissions and password, it disables the account", %{conn: conn, user: user} do
      response =
        conn
        |> post("/api/pleroma/disable_account", %{"password" => "test"})
        |> json_response(:ok)

      assert response == %{"status" => "success"}
      ObanHelpers.perform_all()

      user = User.get_cached_by_id(user.id)

      assert user.deactivated == true
    end

    test "with valid permissions and invalid password, it returns an error", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/api/pleroma/disable_account", %{"password" => "test1"})
        |> json_response(:ok)

      assert response == %{"error" => "Invalid password."}
      user = User.get_cached_by_id(user.id)

      refute user.deactivated
    end
  end

  describe "GET /api/statusnet/version" do
    test "it returns version in xml format", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/xml")
        |> get("/api/statusnet/version")
        |> response(:ok)

      assert response == "<version>#{Pleroma.Application.named_version()}</version>"
    end

    test "it returns version in json format", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/statusnet/version")
        |> json_response(:ok)

      assert response == "#{Pleroma.Application.named_version()}"
    end
  end

  describe "POST /main/ostatus - remote_subscribe/2" do
    test "renders subscribe form", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/main/ostatus", %{"nickname" => user.nickname, "profile" => ""})
        |> response(:ok)

      refute response =~ "Could not find user"
      assert response =~ "Remotely follow #{user.nickname}"
    end

    test "renders subscribe form with error when user not found", %{conn: conn} do
      response =
        conn
        |> post("/main/ostatus", %{"nickname" => "nickname", "profile" => ""})
        |> response(:ok)

      assert response =~ "Could not find user"
      refute response =~ "Remotely follow"
    end

    test "it redirect to webfinger url", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      conn =
        conn
        |> post("/main/ostatus", %{
          "user" => %{"nickname" => user.nickname, "profile" => user2.ap_id}
        })

      assert redirected_to(conn) ==
               "https://social.heldscal.la/main/ostatussub?profile=#{user.ap_id}"
    end

    test "it renders form with error when user not found", %{conn: conn} do
      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      response =
        conn
        |> post("/main/ostatus", %{"user" => %{"nickname" => "jimm", "profile" => user2.ap_id}})
        |> response(:ok)

      assert response =~ "Something went wrong."
    end
  end

  test "it returns new captcha", %{conn: conn} do
    with_mock Pleroma.Captcha,
      new: fn -> "test_captcha" end do
      resp =
        conn
        |> get("/api/pleroma/captcha")
        |> response(200)

      assert resp == "\"test_captcha\""
      assert called(Pleroma.Captcha.new())
    end
  end

  describe "POST /api/pleroma/change_email" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> post("/api/pleroma/change_email")

      assert json_response(conn, 403) == %{"error" => "Insufficient permissions: write:accounts."}
    end

    test "with proper permissions and invalid password", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "hi",
          "email" => "test@test.com"
        })

      assert json_response(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with proper permissions, valid password and invalid email", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "test",
          "email" => "foobar"
        })

      assert json_response(conn, 200) == %{"error" => "Email has invalid format."}
    end

    test "with proper permissions, valid password and no email", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "test"
        })

      assert json_response(conn, 200) == %{"error" => "Email can't be blank."}
    end

    test "with proper permissions, valid password and blank email", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "test",
          "email" => ""
        })

      assert json_response(conn, 200) == %{"error" => "Email can't be blank."}
    end

    test "with proper permissions, valid password and non unique email", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "test",
          "email" => user.email
        })

      assert json_response(conn, 200) == %{"error" => "Email has already been taken."}
    end

    test "with proper permissions, valid password and valid email", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/pleroma/change_email", %{
          "password" => "test",
          "email" => "cofe@foobar.com"
        })

      assert json_response(conn, 200) == %{"status" => "success"}
    end
  end

  describe "POST /api/pleroma/change_password" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> post("/api/pleroma/change_password")

      assert json_response(conn, 403) == %{"error" => "Insufficient permissions: write:accounts."}
    end

    test "with proper permissions and invalid password", %{conn: conn} do
      conn =
        post(conn, "/api/pleroma/change_password", %{
          "password" => "hi",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with proper permissions, valid password and new password and confirmation not matching",
         %{
           conn: conn
         } do
      conn =
        post(conn, "/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "newpass",
          "new_password_confirmation" => "notnewpass"
        })

      assert json_response(conn, 200) == %{
               "error" => "New password does not match confirmation."
             }
    end

    test "with proper permissions, valid password and invalid new password", %{
      conn: conn
    } do
      conn =
        post(conn, "/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "",
          "new_password_confirmation" => ""
        })

      assert json_response(conn, 200) == %{
               "error" => "New password can't be blank."
             }
    end

    test "with proper permissions, valid password and matching new password and confirmation", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, "/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response(conn, 200) == %{"status" => "success"}
      fetched_user = User.get_cached_by_id(user.id)
      assert Comeonin.Pbkdf2.checkpw("newpass", fetched_user.password_hash) == true
    end
  end

  describe "POST /api/pleroma/delete_account" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> post("/api/pleroma/delete_account")

      assert json_response(conn, 403) ==
               %{"error" => "Insufficient permissions: write:accounts."}
    end

    test "with proper permissions and wrong or missing password", %{conn: conn} do
      for params <- [%{"password" => "hi"}, %{}] do
        ret_conn = post(conn, "/api/pleroma/delete_account", params)

        assert json_response(ret_conn, 200) == %{"error" => "Invalid password."}
      end
    end

    test "with proper permissions and valid password", %{conn: conn} do
      conn = post(conn, "/api/pleroma/delete_account", %{"password" => "test"})

      assert json_response(conn, 200) == %{"status" => "success"}
    end
  end
end
