# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Factory

  describe "account fetching" do
    test "works by id" do
      user = insert(:user)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.id}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == to_string(user.id)

      conn =
        build_conn()
        |> get("/api/v1/accounts/-1")

      assert %{"error" => "Can't find user"} = json_response(conn, 404)
    end

    test "works by nickname" do
      user = insert(:user)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.nickname}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == user.id
    end

    test "works by nickname for remote users" do
      limit_to_local = Pleroma.Config.get([:instance, :limit_to_local_content])
      Pleroma.Config.put([:instance, :limit_to_local_content], false)
      user = insert(:user, nickname: "user@example.com", local: false)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.nickname}")

      Pleroma.Config.put([:instance, :limit_to_local_content], limit_to_local)
      assert %{"id" => id} = json_response(conn, 200)
      assert id == user.id
    end

    test "respects limit_to_local_content == :all for remote user nicknames" do
      limit_to_local = Pleroma.Config.get([:instance, :limit_to_local_content])
      Pleroma.Config.put([:instance, :limit_to_local_content], :all)

      user = insert(:user, nickname: "user@example.com", local: false)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.nickname}")

      Pleroma.Config.put([:instance, :limit_to_local_content], limit_to_local)
      assert json_response(conn, 404)
    end

    test "respects limit_to_local_content == :unauthenticated for remote user nicknames" do
      limit_to_local = Pleroma.Config.get([:instance, :limit_to_local_content])
      Pleroma.Config.put([:instance, :limit_to_local_content], :unauthenticated)

      user = insert(:user, nickname: "user@example.com", local: false)
      reading_user = insert(:user)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.nickname}")

      assert json_response(conn, 404)

      conn =
        build_conn()
        |> assign(:user, reading_user)
        |> get("/api/v1/accounts/#{user.nickname}")

      Pleroma.Config.put([:instance, :limit_to_local_content], limit_to_local)
      assert %{"id" => id} = json_response(conn, 200)
      assert id == user.id
    end

    test "accounts fetches correct account for nicknames beginning with numbers", %{conn: conn} do
      # Need to set an old-style integer ID to reproduce the problem
      # (these are no longer assigned to new accounts but were preserved
      # for existing accounts during the migration to flakeIDs)
      user_one = insert(:user, %{id: 1212})
      user_two = insert(:user, %{nickname: "#{user_one.id}garbage"})

      resp_one =
        conn
        |> get("/api/v1/accounts/#{user_one.id}")

      resp_two =
        conn
        |> get("/api/v1/accounts/#{user_two.nickname}")

      resp_three =
        conn
        |> get("/api/v1/accounts/#{user_two.id}")

      acc_one = json_response(resp_one, 200)
      acc_two = json_response(resp_two, 200)
      acc_three = json_response(resp_three, 200)
      refute acc_one == acc_two
      assert acc_two == acc_three
    end
  end

  describe "user timelines" do
    test "gets a users statuses", %{conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)
      user_three = insert(:user)

      {:ok, user_three} = User.follow(user_three, user_one)

      {:ok, activity} = CommonAPI.post(user_one, %{"status" => "HI!!!"})

      {:ok, direct_activity} =
        CommonAPI.post(user_one, %{
          "status" => "Hi, @#{user_two.nickname}.",
          "visibility" => "direct"
        })

      {:ok, private_activity} =
        CommonAPI.post(user_one, %{"status" => "private", "visibility" => "private"})

      resp =
        conn
        |> get("/api/v1/accounts/#{user_one.id}/statuses")

      assert [%{"id" => id}] = json_response(resp, 200)
      assert id == to_string(activity.id)

      resp =
        conn
        |> assign(:user, user_two)
        |> get("/api/v1/accounts/#{user_one.id}/statuses")

      assert [%{"id" => id_one}, %{"id" => id_two}] = json_response(resp, 200)
      assert id_one == to_string(direct_activity.id)
      assert id_two == to_string(activity.id)

      resp =
        conn
        |> assign(:user, user_three)
        |> get("/api/v1/accounts/#{user_one.id}/statuses")

      assert [%{"id" => id_one}, %{"id" => id_two}] = json_response(resp, 200)
      assert id_one == to_string(private_activity.id)
      assert id_two == to_string(activity.id)
    end

    test "unimplemented pinned statuses feature", %{conn: conn} do
      note = insert(:note_activity)
      user = User.get_cached_by_ap_id(note.data["actor"])

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")

      assert json_response(conn, 200) == []
    end

    test "gets an users media", %{conn: conn} do
      note = insert(:note_activity)
      user = User.get_cached_by_ap_id(note.data["actor"])

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %{id: media_id}} = ActivityPub.upload(file, actor: user.ap_id)

      {:ok, image_post} = CommonAPI.post(user, %{"status" => "cofe", "media_ids" => [media_id]})

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"only_media" => "true"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(image_post.id)

      conn =
        build_conn()
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"only_media" => "1"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(image_post.id)
    end

    test "gets a user's statuses without reblogs", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{"status" => "HI!!!"})
      {:ok, _, _} = CommonAPI.repeat(post.id, user)

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"exclude_reblogs" => "true"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(post.id)

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"exclude_reblogs" => "1"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(post.id)
    end

    test "filters user's statuses by a hashtag", %{conn: conn} do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{"status" => "#hashtag"})
      {:ok, _post} = CommonAPI.post(user, %{"status" => "hashtag"})

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"tagged" => "hashtag"})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(post.id)
    end

    test "the user views their own timelines and excludes direct messages", %{conn: conn} do
      user = insert(:user)
      {:ok, public_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})
      {:ok, _direct_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{user.id}/statuses", %{"exclude_visibilities" => ["direct"]})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(public_activity.id)
    end
  end

  describe "followers" do
    test "getting followers", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn =
        conn
        |> get("/api/v1/accounts/#{other_user.id}/followers")

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(user.id)
    end

    test "getting followers, hide_followers", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user, hide_followers: true)
      {:ok, _user} = User.follow(user, other_user)

      conn =
        conn
        |> get("/api/v1/accounts/#{other_user.id}/followers")

      assert [] == json_response(conn, 200)
    end

    test "getting followers, hide_followers, same user requesting", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user, hide_followers: true)
      {:ok, _user} = User.follow(user, other_user)

      conn =
        conn
        |> assign(:user, other_user)
        |> get("/api/v1/accounts/#{other_user.id}/followers")

      refute [] == json_response(conn, 200)
    end

    test "getting followers, pagination", %{conn: conn} do
      user = insert(:user)
      follower1 = insert(:user)
      follower2 = insert(:user)
      follower3 = insert(:user)
      {:ok, _} = User.follow(follower1, user)
      {:ok, _} = User.follow(follower2, user)
      {:ok, _} = User.follow(follower3, user)

      conn =
        conn
        |> assign(:user, user)

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/followers?since_id=#{follower1.id}")

      assert [%{"id" => id3}, %{"id" => id2}] = json_response(res_conn, 200)
      assert id3 == follower3.id
      assert id2 == follower2.id

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/followers?max_id=#{follower3.id}")

      assert [%{"id" => id2}, %{"id" => id1}] = json_response(res_conn, 200)
      assert id2 == follower2.id
      assert id1 == follower1.id

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/followers?limit=1&max_id=#{follower3.id}")

      assert [%{"id" => id2}] = json_response(res_conn, 200)
      assert id2 == follower2.id

      assert [link_header] = get_resp_header(res_conn, "link")
      assert link_header =~ ~r/min_id=#{follower2.id}/
      assert link_header =~ ~r/max_id=#{follower2.id}/
    end
  end

  describe "following" do
    test "getting following", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/following")

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(other_user.id)
    end

    test "getting following, hide_follows", %{conn: conn} do
      user = insert(:user, hide_follows: true)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/following")

      assert [] == json_response(conn, 200)
    end

    test "getting following, hide_follows, same user requesting", %{conn: conn} do
      user = insert(:user, hide_follows: true)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{user.id}/following")

      refute [] == json_response(conn, 200)
    end

    test "getting following, pagination", %{conn: conn} do
      user = insert(:user)
      following1 = insert(:user)
      following2 = insert(:user)
      following3 = insert(:user)
      {:ok, _} = User.follow(user, following1)
      {:ok, _} = User.follow(user, following2)
      {:ok, _} = User.follow(user, following3)

      conn =
        conn
        |> assign(:user, user)

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/following?since_id=#{following1.id}")

      assert [%{"id" => id3}, %{"id" => id2}] = json_response(res_conn, 200)
      assert id3 == following3.id
      assert id2 == following2.id

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/following?max_id=#{following3.id}")

      assert [%{"id" => id2}, %{"id" => id1}] = json_response(res_conn, 200)
      assert id2 == following2.id
      assert id1 == following1.id

      res_conn =
        conn
        |> get("/api/v1/accounts/#{user.id}/following?limit=1&max_id=#{following3.id}")

      assert [%{"id" => id2}] = json_response(res_conn, 200)
      assert id2 == following2.id

      assert [link_header] = get_resp_header(res_conn, "link")
      assert link_header =~ ~r/min_id=#{following2.id}/
      assert link_header =~ ~r/max_id=#{following2.id}/
    end
  end

  describe "follow/unfollow" do
    test "following / unfollowing a user", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/follow")

      assert %{"id" => _id, "following" => true} = json_response(conn, 200)

      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/unfollow")

      assert %{"id" => _id, "following" => false} = json_response(conn, 200)

      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/follows", %{"uri" => other_user.nickname})

      assert %{"id" => id} = json_response(conn, 200)
      assert id == to_string(other_user.id)
    end

    test "following without reblogs" do
      follower = insert(:user)
      followed = insert(:user)
      other_user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, follower)
        |> post("/api/v1/accounts/#{followed.id}/follow?reblogs=false")

      assert %{"showing_reblogs" => false} = json_response(conn, 200)

      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "hey"})
      {:ok, reblog, _} = CommonAPI.repeat(activity.id, followed)

      conn =
        build_conn()
        |> assign(:user, User.get_cached_by_id(follower.id))
        |> get("/api/v1/timelines/home")

      assert [] == json_response(conn, 200)

      conn =
        build_conn()
        |> assign(:user, User.get_cached_by_id(follower.id))
        |> post("/api/v1/accounts/#{followed.id}/follow?reblogs=true")

      assert %{"showing_reblogs" => true} = json_response(conn, 200)

      conn =
        build_conn()
        |> assign(:user, User.get_cached_by_id(follower.id))
        |> get("/api/v1/timelines/home")

      expected_activity_id = reblog.id
      assert [%{"id" => ^expected_activity_id}] = json_response(conn, 200)
    end

    test "following / unfollowing errors" do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)

      # self follow
      conn_res = post(conn, "/api/v1/accounts/#{user.id}/follow")
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)

      # self unfollow
      user = User.get_cached_by_id(user.id)
      conn_res = post(conn, "/api/v1/accounts/#{user.id}/unfollow")
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)

      # self follow via uri
      user = User.get_cached_by_id(user.id)
      conn_res = post(conn, "/api/v1/follows", %{"uri" => user.nickname})
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)

      # follow non existing user
      conn_res = post(conn, "/api/v1/accounts/doesntexist/follow")
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)

      # follow non existing user via uri
      conn_res = post(conn, "/api/v1/follows", %{"uri" => "doesntexist"})
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)

      # unfollow non existing user
      conn_res = post(conn, "/api/v1/accounts/doesntexist/unfollow")
      assert %{"error" => "Record not found"} = json_response(conn_res, 404)
    end
  end

  describe "mute/unmute" do
    test "with notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/mute")

      response = json_response(conn, 200)

      assert %{"id" => _id, "muting" => true, "muting_notifications" => true} = response
      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/unmute")

      response = json_response(conn, 200)
      assert %{"id" => _id, "muting" => false, "muting_notifications" => false} = response
    end

    test "without notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/mute", %{"notifications" => "false"})

      response = json_response(conn, 200)

      assert %{"id" => _id, "muting" => true, "muting_notifications" => false} = response
      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/accounts/#{other_user.id}/unmute")

      response = json_response(conn, 200)
      assert %{"id" => _id, "muting" => false, "muting_notifications" => false} = response
    end
  end

  describe "pinned statuses" do
    setup do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "HI!!!"})

      [user: user, activity: activity]
    end

    test "returns pinned statuses", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.pin(activity.id, user)

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")
        |> json_response(200)

      id_str = to_string(activity.id)

      assert [%{"id" => ^id_str, "pinned" => true}] = result
    end
  end

  test "blocking / unblocking a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/accounts/#{other_user.id}/block")

    assert %{"id" => _id, "blocking" => true} = json_response(conn, 200)

    user = User.get_cached_by_id(user.id)

    conn =
      build_conn()
      |> assign(:user, user)
      |> post("/api/v1/accounts/#{other_user.id}/unblock")

    assert %{"id" => _id, "blocking" => false} = json_response(conn, 200)
  end

  describe "create account by app" do
    setup do
      valid_params = %{
        username: "lain",
        email: "lain@example.org",
        password: "PlzDontHackLain",
        agreement: true
      }

      [valid_params: valid_params]
    end

    test "Account registration via Application", %{conn: conn} do
      conn =
        conn
        |> post("/api/v1/apps", %{
          client_name: "client_name",
          redirect_uris: "urn:ietf:wg:oauth:2.0:oob",
          scopes: "read, write, follow"
        })

      %{
        "client_id" => client_id,
        "client_secret" => client_secret,
        "id" => _,
        "name" => "client_name",
        "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob",
        "vapid_key" => _,
        "website" => nil
      } = json_response(conn, 200)

      conn =
        conn
        |> post("/oauth/token", %{
          grant_type: "client_credentials",
          client_id: client_id,
          client_secret: client_secret
        })

      assert %{"access_token" => token, "refresh_token" => refresh, "scope" => scope} =
               json_response(conn, 200)

      assert token
      token_from_db = Repo.get_by(Token, token: token)
      assert token_from_db
      assert refresh
      assert scope == "read write follow"

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/api/v1/accounts", %{
          username: "lain",
          email: "lain@example.org",
          password: "PlzDontHackLain",
          bio: "Test Bio",
          agreement: true
        })

      %{
        "access_token" => token,
        "created_at" => _created_at,
        "scope" => _scope,
        "token_type" => "Bearer"
      } = json_response(conn, 200)

      token_from_db = Repo.get_by(Token, token: token)
      assert token_from_db
      token_from_db = Repo.preload(token_from_db, :user)
      assert token_from_db.user

      assert token_from_db.user.confirmation_pending
    end

    test "returns error when user already registred", %{conn: conn, valid_params: valid_params} do
      _user = insert(:user, email: "lain@example.org")
      app_token = insert(:oauth_token, user: nil)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> app_token.token)

      res = post(conn, "/api/v1/accounts", valid_params)
      assert json_response(res, 400) == %{"error" => "{\"email\":[\"has already been taken\"]}"}
    end

    test "rate limit", %{conn: conn} do
      app_token = insert(:oauth_token, user: nil)

      conn =
        put_req_header(conn, "authorization", "Bearer " <> app_token.token)
        |> Map.put(:remote_ip, {15, 15, 15, 15})

      for i <- 1..5 do
        conn =
          conn
          |> post("/api/v1/accounts", %{
            username: "#{i}lain",
            email: "#{i}lain@example.org",
            password: "PlzDontHackLain",
            agreement: true
          })

        %{
          "access_token" => token,
          "created_at" => _created_at,
          "scope" => _scope,
          "token_type" => "Bearer"
        } = json_response(conn, 200)

        token_from_db = Repo.get_by(Token, token: token)
        assert token_from_db
        token_from_db = Repo.preload(token_from_db, :user)
        assert token_from_db.user

        assert token_from_db.user.confirmation_pending
      end

      conn =
        conn
        |> post("/api/v1/accounts", %{
          username: "6lain",
          email: "6lain@example.org",
          password: "PlzDontHackLain",
          agreement: true
        })

      assert json_response(conn, :too_many_requests) == %{"error" => "Throttled"}
    end

    test "returns bad_request if missing required params", %{
      conn: conn,
      valid_params: valid_params
    } do
      app_token = insert(:oauth_token, user: nil)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> app_token.token)

      res = post(conn, "/api/v1/accounts", valid_params)
      assert json_response(res, 200)

      [{127, 0, 0, 1}, {127, 0, 0, 2}, {127, 0, 0, 3}, {127, 0, 0, 4}]
      |> Stream.zip(valid_params)
      |> Enum.each(fn {ip, {attr, _}} ->
        res =
          conn
          |> Map.put(:remote_ip, ip)
          |> post("/api/v1/accounts", Map.delete(valid_params, attr))
          |> json_response(400)

        assert res == %{"error" => "Missing parameters"}
      end)
    end

    test "returns forbidden if token is invalid", %{conn: conn, valid_params: valid_params} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> "invalid-token")

      res = post(conn, "/api/v1/accounts", valid_params)
      assert json_response(res, 403) == %{"error" => "Invalid credentials"}
    end
  end

  describe "GET /api/v1/accounts/:id/lists - account_lists" do
    test "returns lists to which the account belongs", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      assert {:ok, %Pleroma.List{} = list} = Pleroma.List.create("Test List", user)
      {:ok, %{following: _following}} = Pleroma.List.follow(list, other_user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{other_user.id}/lists")
        |> json_response(200)

      assert res == [%{"id" => to_string(list.id), "title" => "Test List"}]
    end
  end

  describe "verify_credentials" do
    test "verify_credentials", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/verify_credentials")

      response = json_response(conn, 200)

      assert %{"id" => id, "source" => %{"privacy" => "public"}} = response
      assert response["pleroma"]["chat_token"]
      assert id == to_string(user.id)
    end

    test "verify_credentials default scope unlisted", %{conn: conn} do
      user = insert(:user, default_scope: "unlisted")

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/verify_credentials")

      assert %{"id" => id, "source" => %{"privacy" => "unlisted"}} = json_response(conn, 200)
      assert id == to_string(user.id)
    end

    test "locked accounts", %{conn: conn} do
      user = insert(:user, default_scope: "private")

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/verify_credentials")

      assert %{"id" => id, "source" => %{"privacy" => "private"}} = json_response(conn, 200)
      assert id == to_string(user.id)
    end
  end

  describe "user relationships" do
    test "returns the relationships for the current user", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, user} = User.follow(user, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/relationships", %{"id" => [other_user.id]})

      assert [relationship] = json_response(conn, 200)

      assert to_string(other_user.id) == relationship["id"]
    end

    test "returns an empty list on a bad request", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/relationships", %{})

      assert [] = json_response(conn, 200)
    end
  end

  test "getting a list of mutes", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, user} = User.mute(user, other_user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/mutes")

    other_user_id = to_string(other_user.id)
    assert [%{"id" => ^other_user_id}] = json_response(conn, 200)
  end

  test "getting a list of blocks", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, user} = User.block(user, other_user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/blocks")

    other_user_id = to_string(other_user.id)
    assert [%{"id" => ^other_user_id}] = json_response(conn, 200)
  end
end
