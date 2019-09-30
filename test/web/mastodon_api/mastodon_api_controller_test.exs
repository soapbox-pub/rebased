# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Ecto.Changeset
  alias Pleroma.Config
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Push

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Swoosh.TestAssertions
  import Tesla.Mock

  @image "data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7"

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance, :public])
  clear_config([:rich_media, :enabled])

  test "Conversations", %{conn: conn} do
    user_one = insert(:user)
    user_two = insert(:user)
    user_three = insert(:user)

    {:ok, user_two} = User.follow(user_two, user_one)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}, @#{user_three.nickname}!",
        "visibility" => "direct"
      })

    {:ok, _follower_only} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "private"
      })

    res_conn =
      conn
      |> assign(:user, user_one)
      |> get("/api/v1/conversations")

    assert response = json_response(res_conn, 200)

    assert [
             %{
               "id" => res_id,
               "accounts" => res_accounts,
               "last_status" => res_last_status,
               "unread" => unread
             }
           ] = response

    account_ids = Enum.map(res_accounts, & &1["id"])
    assert length(res_accounts) == 2
    assert user_two.id in account_ids
    assert user_three.id in account_ids
    assert is_binary(res_id)
    assert unread == true
    assert res_last_status["id"] == direct.id

    # Apparently undocumented API endpoint
    res_conn =
      conn
      |> assign(:user, user_one)
      |> post("/api/v1/conversations/#{res_id}/read")

    assert response = json_response(res_conn, 200)
    assert length(response["accounts"]) == 2
    assert response["last_status"]["id"] == direct.id
    assert response["unread"] == false

    # (vanilla) Mastodon frontend behaviour
    res_conn =
      conn
      |> assign(:user, user_one)
      |> get("/api/v1/statuses/#{res_last_status["id"]}/context")

    assert %{"ancestors" => [], "descendants" => []} == json_response(res_conn, 200)
  end

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
    user = insert(:user, %{info: %User.Info{default_scope: "unlisted"}})

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/accounts/verify_credentials")

    assert %{"id" => id, "source" => %{"privacy" => "unlisted"}} = json_response(conn, 200)
    assert id == to_string(user.id)
  end

  test "apps/verify_credentials", %{conn: conn} do
    token = insert(:oauth_token)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> get("/api/v1/apps/verify_credentials")

    app = Repo.preload(token, :app).app

    expected = %{
      "name" => app.client_name,
      "website" => app.website,
      "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
    }

    assert expected == json_response(conn, 200)
  end

  test "user avatar can be set", %{conn: conn} do
    user = insert(:user)
    avatar_image = File.read!("test/fixtures/avatar_data_uri")

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_avatar", %{img: avatar_image})

    user = refresh_record(user)

    assert %{
             "name" => _,
             "type" => _,
             "url" => [
               %{
                 "href" => _,
                 "mediaType" => _,
                 "type" => _
               }
             ]
           } = user.avatar

    assert %{"url" => _} = json_response(conn, 200)
  end

  test "user avatar can be reset", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_avatar", %{img: ""})

    user = User.get_cached_by_id(user.id)

    assert user.avatar == nil

    assert %{"url" => nil} = json_response(conn, 200)
  end

  test "can set profile banner", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_banner", %{"banner" => @image})

    user = refresh_record(user)
    assert user.info.banner["type"] == "Image"

    assert %{"url" => _} = json_response(conn, 200)
  end

  test "can reset profile banner", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_banner", %{"banner" => ""})

    user = refresh_record(user)
    assert user.info.banner == %{}

    assert %{"url" => nil} = json_response(conn, 200)
  end

  test "background image can be set", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_background", %{"img" => @image})

    user = refresh_record(user)
    assert user.info.background["type"] == "Image"
    assert %{"url" => _} = json_response(conn, 200)
  end

  test "background image can be reset", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> patch("/api/v1/pleroma/accounts/update_background", %{"img" => ""})

    user = refresh_record(user)
    assert user.info.background == %{}
    assert %{"url" => nil} = json_response(conn, 200)
  end

  test "creates an oauth app", %{conn: conn} do
    user = insert(:user)
    app_attrs = build(:oauth_app)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/apps", %{
        client_name: app_attrs.client_name,
        redirect_uris: app_attrs.redirect_uris
      })

    [app] = Repo.all(App)

    expected = %{
      "name" => app.client_name,
      "website" => app.website,
      "client_id" => app.client_id,
      "client_secret" => app.client_secret,
      "id" => app.id |> to_string(),
      "redirect_uri" => app.redirect_uris,
      "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
    }

    assert expected == json_response(conn, 200)
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

  describe "media upload" do
    setup do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)

      image = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      [conn: conn, image: image]
    end

    clear_config([:media_proxy])
    clear_config([Pleroma.Upload])

    test "returns uploaded image", %{conn: conn, image: image} do
      desc = "Description of the image"

      media =
        conn
        |> post("/api/v1/media", %{"file" => image, "description" => desc})
        |> json_response(:ok)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      object = Repo.get(Object, media["id"])
      assert object.data["actor"] == User.ap_id(conn.assigns[:user])
    end
  end

  describe "locked accounts" do
    test "verify_credentials", %{conn: conn} do
      user = insert(:user, %{info: %User.Info{default_scope: "private"}})

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/verify_credentials")

      assert %{"id" => id, "source" => %{"privacy" => "private"}} = json_response(conn, 200)
      assert id == to_string(user.id)
    end
  end

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
  end

  describe "/api/v1/pleroma/mascot" do
    test "mascot upload", %{conn: conn} do
      user = insert(:user)

      non_image_file = %Plug.Upload{
        content_type: "audio/mpeg",
        path: Path.absname("test/fixtures/sound.mp3"),
        filename: "sound.mp3"
      }

      conn =
        conn
        |> assign(:user, user)
        |> put("/api/v1/pleroma/mascot", %{"file" => non_image_file})

      assert json_response(conn, 415)

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        build_conn()
        |> assign(:user, user)
        |> put("/api/v1/pleroma/mascot", %{"file" => file})

      assert %{"id" => _, "type" => image} = json_response(conn, 200)
    end

    test "mascot retrieving", %{conn: conn} do
      user = insert(:user)
      # When user hasn't set a mascot, we should just get pleroma tan back
      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/mascot")

      assert %{"url" => url} = json_response(conn, 200)
      assert url =~ "pleroma-fox-tan-smol"

      # When a user sets their mascot, we should get that back
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        build_conn()
        |> assign(:user, user)
        |> put("/api/v1/pleroma/mascot", %{"file" => file})

      assert json_response(conn, 200)

      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/pleroma/mascot")

      assert %{"url" => url, "type" => "image"} = json_response(conn, 200)
      assert url =~ "an_image"
    end
  end

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
    other_user = insert(:user, %{info: %{hide_followers: true}})
    {:ok, _user} = User.follow(user, other_user)

    conn =
      conn
      |> get("/api/v1/accounts/#{other_user.id}/followers")

    assert [] == json_response(conn, 200)
  end

  test "getting followers, hide_followers, same user requesting", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user, %{info: %{hide_followers: true}})
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
    user = insert(:user, %{info: %{hide_follows: true}})
    other_user = insert(:user)
    {:ok, user} = User.follow(user, other_user)

    conn =
      conn
      |> get("/api/v1/accounts/#{user.id}/following")

    assert [] == json_response(conn, 200)
  end

  test "getting following, hide_follows, same user requesting", %{conn: conn} do
    user = insert(:user, %{info: %{hide_follows: true}})
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
      |> assign(:user, follower)
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

  describe "subscribing / unsubscribing" do
    test "subscribing / unsubscribing to a user", %{conn: conn} do
      user = insert(:user)
      subscription_target = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/accounts/#{subscription_target.id}/subscribe")

      assert %{"id" => _id, "subscribing" => true} = json_response(conn, 200)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/pleroma/accounts/#{subscription_target.id}/unsubscribe")

      assert %{"id" => _id, "subscribing" => false} = json_response(conn, 200)
    end
  end

  describe "subscribing" do
    test "returns 404 when subscription_target not found", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/accounts/target_id/subscribe")

      assert %{"error" => "Record not found"} = json_response(conn, 404)
    end
  end

  describe "unsubscribing" do
    test "returns 404 when subscription_target not found", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/accounts/target_id/unsubscribe")

      assert %{"error" => "Record not found"} = json_response(conn, 404)
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

  test "unimplemented follow_requests, blocks, domain blocks" do
    user = insert(:user)

    ["blocks", "domain_blocks", "follow_requests"]
    |> Enum.each(fn endpoint ->
      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/#{endpoint}")

      assert [] = json_response(conn, 200)
    end)
  end

  test "returns the favorites of a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _} = CommonAPI.post(other_user, %{"status" => "bla"})
    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "traps are happy"})

    {:ok, _, _} = CommonAPI.favorite(activity.id, user)

    first_conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/favourites")

    assert [status] = json_response(first_conn, 200)
    assert status["id"] == to_string(activity.id)

    assert [{"link", _link_header}] =
             Enum.filter(first_conn.resp_headers, fn element -> match?({"link", _}, element) end)

    # Honours query params
    {:ok, second_activity} =
      CommonAPI.post(other_user, %{
        "status" =>
          "Trees Are Never Sad Look At Them Every Once In Awhile They're Quite Beautiful."
      })

    {:ok, _, _} = CommonAPI.favorite(second_activity.id, user)

    last_like = status["id"]

    second_conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/favourites?since_id=#{last_like}")

    assert [second_status] = json_response(second_conn, 200)
    assert second_status["id"] == to_string(second_activity.id)

    third_conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/favourites?limit=0")

    assert [] = json_response(third_conn, 200)
  end

  describe "getting favorites timeline of specified user" do
    setup do
      [current_user, user] = insert_pair(:user, %{info: %{hide_favorites: false}})
      [current_user: current_user, user: user]
    end

    test "returns list of statuses favorited by specified user", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      [activity | _] = insert_pair(:note_activity)
      CommonAPI.favorite(activity.id, user)

      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      [like] = response

      assert length(response) == 1
      assert like["id"] == activity.id
    end

    test "returns favorites for specified user_id when user is not logged in", %{
      conn: conn,
      user: user
    } do
      activity = insert(:note_activity)
      CommonAPI.favorite(activity.id, user)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert length(response) == 1
    end

    test "returns favorited DM only when user is logged in and he is one of recipients", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      {:ok, direct} =
        CommonAPI.post(current_user, %{
          "status" => "Hi @#{user.nickname}!",
          "visibility" => "direct"
        })

      CommonAPI.favorite(direct.id, user)

      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert length(response) == 1

      anonymous_response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert Enum.empty?(anonymous_response)
    end

    test "does not return others' favorited DM when user is not one of recipients", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      user_two = insert(:user)

      {:ok, direct} =
        CommonAPI.post(user_two, %{
          "status" => "Hi @#{user.nickname}!",
          "visibility" => "direct"
        })

      CommonAPI.favorite(direct.id, user)

      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "paginates favorites using since_id and max_id", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      activities = insert_list(10, :note_activity)

      Enum.each(activities, fn activity ->
        CommonAPI.favorite(activity.id, user)
      end)

      third_activity = Enum.at(activities, 2)
      seventh_activity = Enum.at(activities, 6)

      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites", %{
          since_id: third_activity.id,
          max_id: seventh_activity.id
        })
        |> json_response(:ok)

      assert length(response) == 3
      refute third_activity in response
      refute seventh_activity in response
    end

    test "limits favorites using limit parameter", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      7
      |> insert_list(:note_activity)
      |> Enum.each(fn activity ->
        CommonAPI.favorite(activity.id, user)
      end)

      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites", %{limit: "3"})
        |> json_response(:ok)

      assert length(response) == 3
    end

    test "returns empty response when user does not have any favorited statuses", %{
      conn: conn,
      current_user: current_user,
      user: user
    } do
      response =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "returns 404 error when specified user is not exist", %{conn: conn} do
      conn = get(conn, "/api/v1/pleroma/accounts/test/favourites")

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end

    test "returns 403 error when user has hidden own favorites", %{
      conn: conn,
      current_user: current_user
    } do
      user = insert(:user, %{info: %{hide_favorites: true}})
      activity = insert(:note_activity)
      CommonAPI.favorite(activity.id, user)

      conn =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert json_response(conn, 403) == %{"error" => "Can't get favorites"}
    end

    test "hides favorites for new users by default", %{conn: conn, current_user: current_user} do
      user = insert(:user)
      activity = insert(:note_activity)
      CommonAPI.favorite(activity.id, user)

      conn =
        conn
        |> assign(:user, current_user)
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert user.info.hide_favorites
      assert json_response(conn, 403) == %{"error" => "Can't get favorites"}
    end
  end

  test "get instance information", %{conn: conn} do
    conn = get(conn, "/api/v1/instance")
    assert result = json_response(conn, 200)

    email = Config.get([:instance, :email])
    # Note: not checking for "max_toot_chars" since it's optional
    assert %{
             "uri" => _,
             "title" => _,
             "description" => _,
             "version" => _,
             "email" => from_config_email,
             "urls" => %{
               "streaming_api" => _
             },
             "stats" => _,
             "thumbnail" => _,
             "languages" => _,
             "registrations" => _,
             "poll_limits" => _
           } = result

    assert email == from_config_email
  end

  test "get instance stats", %{conn: conn} do
    user = insert(:user, %{local: true})

    user2 = insert(:user, %{local: true})
    {:ok, _user2} = User.deactivate(user2, !user2.info.deactivated)

    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})

    {:ok, _} = CommonAPI.post(user, %{"status" => "cofe"})

    # Stats should count users with missing or nil `info.deactivated` value

    {:ok, _user} =
      user.id
      |> User.get_cached_by_id()
      |> User.update_info(&Changeset.change(&1, %{deactivated: nil}))

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance")

    assert result = json_response(conn, 200)

    stats = result["stats"]

    assert stats
    assert stats["user_count"] == 1
    assert stats["status_count"] == 1
    assert stats["domain_count"] == 2
  end

  test "get peers", %{conn: conn} do
    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance/peers")

    assert result = json_response(conn, 200)

    assert ["peer1.com", "peer2.com"] == Enum.sort(result)
  end

  test "put settings", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/web/settings", %{"data" => %{"programming" => "socks"}})

    assert _result = json_response(conn, 200)

    user = User.get_cached_by_ap_id(user.ap_id)
    assert user.info.settings == %{"programming" => "socks"}
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

  describe "link headers" do
    test "preserves parameters in link headers", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity1} =
        CommonAPI.post(other_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "public"
        })

      {:ok, activity2} =
        CommonAPI.post(other_user, %{
          "status" => "hi @#{user.nickname}",
          "visibility" => "public"
        })

      notification1 = Repo.get_by(Notification, activity_id: activity1.id)
      notification2 = Repo.get_by(Notification, activity_id: activity2.id)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/notifications", %{media_only: true})

      assert [link_header] = get_resp_header(conn, "link")
      assert link_header =~ ~r/media_only=true/
      assert link_header =~ ~r/min_id=#{notification2.id}/
      assert link_header =~ ~r/max_id=#{notification1.id}/
    end
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

  describe "custom emoji" do
    test "with tags", %{conn: conn} do
      [emoji | _body] =
        conn
        |> get("/api/v1/custom_emojis")
        |> json_response(200)

      assert Map.has_key?(emoji, "shortcode")
      assert Map.has_key?(emoji, "static_url")
      assert Map.has_key?(emoji, "tags")
      assert is_list(emoji["tags"])
      assert Map.has_key?(emoji, "category")
      assert Map.has_key?(emoji, "url")
      assert Map.has_key?(emoji, "visible_in_picker")
    end
  end

  describe "index/2 redirections" do
    setup %{conn: conn} do
      session_opts = [
        store: :cookie,
        key: "_test",
        signing_salt: "cooldude"
      ]

      conn =
        conn
        |> Plug.Session.call(Plug.Session.init(session_opts))
        |> fetch_session()

      test_path = "/web/statuses/test"
      %{conn: conn, path: test_path}
    end

    test "redirects not logged-in users to the login page", %{conn: conn, path: path} do
      conn = get(conn, path)

      assert conn.status == 302
      assert redirected_to(conn) == "/web/login"
    end

    test "redirects not logged-in users to the login page on private instances", %{
      conn: conn,
      path: path
    } do
      Config.put([:instance, :public], false)

      conn = get(conn, path)

      assert conn.status == 302
      assert redirected_to(conn) == "/web/login"
    end

    test "does not redirect logged in users to the login page", %{conn: conn, path: path} do
      token = insert(:oauth_token)

      conn =
        conn
        |> assign(:user, token.user)
        |> put_session(:oauth_token, token.token)
        |> get(path)

      assert conn.status == 200
    end

    test "saves referer path to session", %{conn: conn, path: path} do
      conn = get(conn, path)
      return_to = Plug.Conn.get_session(conn, :return_to)

      assert return_to == path
    end

    test "redirects to the saved path after log in", %{conn: conn, path: path} do
      app = insert(:oauth_app, client_name: "Mastodon-Local", redirect_uris: ".")
      auth = insert(:oauth_authorization, app: app)

      conn =
        conn
        |> put_session(:return_to, path)
        |> get("/web/login", %{code: auth.token})

      assert conn.status == 302
      assert redirected_to(conn) == path
    end

    test "redirects to the getting-started page when referer is not present", %{conn: conn} do
      app = insert(:oauth_app, client_name: "Mastodon-Local", redirect_uris: ".")
      auth = insert(:oauth_authorization, app: app)

      conn = get(conn, "/web/login", %{code: auth.token})

      assert conn.status == 302
      assert redirected_to(conn) == "/web/getting-started"
    end
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

      assert token_from_db.user.info.confirmation_pending
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

        assert token_from_db.user.info.confirmation_pending
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

  describe "GET /api/v1/polls/:id" do
    test "returns poll entity for object id", %{conn: conn} do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Pleroma does",
          "poll" => %{"options" => ["what Mastodon't", "n't what Mastodoes"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/polls/#{object.id}")

      response = json_response(conn, 200)
      id = to_string(object.id)
      assert %{"id" => ^id, "expired" => false, "multiple" => false} = response
    end

    test "does not expose polls for private statuses", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Pleroma does",
          "poll" => %{"options" => ["what Mastodon't", "n't what Mastodoes"], "expires_in" => 20},
          "visibility" => "private"
        })

      object = Object.normalize(activity)

      conn =
        conn
        |> assign(:user, other_user)
        |> get("/api/v1/polls/#{object.id}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/polls/:id/votes" do
    test "votes are added to the poll", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "A very delicious sandwich",
          "poll" => %{
            "options" => ["Lettuce", "Grilled Bacon", "Tomato"],
            "expires_in" => 20,
            "multiple" => true
          }
        })

      object = Object.normalize(activity)

      conn =
        conn
        |> assign(:user, other_user)
        |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [0, 1, 2]})

      assert json_response(conn, 200)
      object = Object.get_by_id(object.id)

      assert Enum.all?(object.data["anyOf"], fn %{"replies" => %{"totalItems" => total_items}} ->
               total_items == 1
             end)
    end

    test "author can't vote", %{conn: conn} do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      assert conn
             |> assign(:user, user)
             |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [1]})
             |> json_response(422) == %{"error" => "Poll's author can't vote"}

      object = Object.get_by_id(object.id)

      refute Enum.at(object.data["oneOf"], 1)["replies"]["totalItems"] == 1
    end

    test "does not allow multiple choices on a single-choice question", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "The glass is",
          "poll" => %{"options" => ["half empty", "half full"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      assert conn
             |> assign(:user, other_user)
             |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [0, 1]})
             |> json_response(422) == %{"error" => "Too many choices"}

      object = Object.get_by_id(object.id)

      refute Enum.any?(object.data["oneOf"], fn %{"replies" => %{"totalItems" => total_items}} ->
               total_items == 1
             end)
    end

    test "does not allow choice index to be greater than options count", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20}
        })

      object = Object.normalize(activity)

      conn =
        conn
        |> assign(:user, other_user)
        |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [2]})

      assert json_response(conn, 422) == %{"error" => "Invalid indices"}
    end

    test "returns 404 error when object is not exist", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/polls/1/votes", %{"choices" => [0]})

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end

    test "returns 404 when poll is private and not available for user", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Am I cute?",
          "poll" => %{"options" => ["Yes", "No"], "expires_in" => 20},
          "visibility" => "private"
        })

      object = Object.normalize(activity)

      conn =
        conn
        |> assign(:user, other_user)
        |> post("/api/v1/polls/#{object.id}/votes", %{"choices" => [0]})

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end
  end

  describe "POST /auth/password, with valid parameters" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = post(conn, "/auth/password?email=#{user.email}")
      %{conn: conn, user: user}
    end

    test "it returns 204", %{conn: conn} do
      assert json_response(conn, :no_content)
    end

    test "it creates a PasswordResetToken record for user", %{user: user} do
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)
      assert token_record
    end

    test "it sends an email to user", %{user: user} do
      ObanHelpers.perform_all()
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)

      email = Pleroma.Emails.UserEmail.password_reset_email(user, token_record.token)
      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: email.html_body
      )
    end
  end

  describe "POST /auth/password, with invalid parameters" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end

    test "it returns 404 when user is not found", %{conn: conn, user: user} do
      conn = post(conn, "/auth/password?email=nonexisting_#{user.email}")
      assert conn.status == 404
      assert conn.resp_body == ""
    end

    test "it returns 400 when user is not local", %{conn: conn, user: user} do
      {:ok, user} = Repo.update(Changeset.change(user, local: false))
      conn = post(conn, "/auth/password?email=#{user.email}")
      assert conn.status == 400
      assert conn.resp_body == ""
    end
  end

  describe "POST /api/v1/pleroma/accounts/confirmation_resend" do
    setup do
      {:ok, user} =
        insert(:user)
        |> User.change_info(&User.Info.confirmation_changeset(&1, need_confirmation: true))
        |> Repo.update()

      assert user.info.confirmation_pending

      [user: user]
    end

    clear_config([:instance, :account_activation_required]) do
      Config.put([:instance, :account_activation_required], true)
    end

    test "resend account confirmation email", %{conn: conn, user: user} do
      conn
      |> assign(:user, user)
      |> post("/api/v1/pleroma/accounts/confirmation_resend?email=#{user.email}")
      |> json_response(:no_content)

      ObanHelpers.perform_all()

      email = Pleroma.Emails.UserEmail.account_confirmation_email(user)
      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: email.html_body
      )
    end
  end

  describe "GET /api/v1/suggestions" do
    setup do
      user = insert(:user)
      other_user = insert(:user)
      host = Config.get([Pleroma.Web.Endpoint, :url, :host])
      url500 = "http://test500?#{host}&#{user.nickname}"
      url200 = "http://test200?#{host}&#{user.nickname}"

      mock(fn
        %{method: :get, url: ^url500} ->
          %Tesla.Env{status: 500, body: "bad request"}

        %{method: :get, url: ^url200} ->
          %Tesla.Env{
            status: 200,
            body:
              ~s([{"acct":"yj455","avatar":"https://social.heldscal.la/avatar/201.jpeg","avatar_static":"https://social.heldscal.la/avatar/s/201.jpeg"}, {"acct":"#{
                other_user.ap_id
              }","avatar":"https://social.heldscal.la/avatar/202.jpeg","avatar_static":"https://social.heldscal.la/avatar/s/202.jpeg"}])
          }
      end)

      [user: user, other_user: other_user]
    end

    clear_config(:suggestions)

    test "returns empty result when suggestions disabled", %{conn: conn, user: user} do
      Config.put([:suggestions, :enabled], false)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/suggestions")
        |> json_response(200)

      assert res == []
    end

    test "returns error", %{conn: conn, user: user} do
      Config.put([:suggestions, :enabled], true)
      Config.put([:suggestions, :third_party_engine], "http://test500?{{host}}&{{user}}")

      assert capture_log(fn ->
               res =
                 conn
                 |> assign(:user, user)
                 |> get("/api/v1/suggestions")
                 |> json_response(500)

               assert res == "Something went wrong"
             end) =~ "Could not retrieve suggestions"
    end

    test "returns suggestions", %{conn: conn, user: user, other_user: other_user} do
      Config.put([:suggestions, :enabled], true)
      Config.put([:suggestions, :third_party_engine], "http://test200?{{host}}&{{user}}")

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/suggestions")
        |> json_response(200)

      assert res == [
               %{
                 "acct" => "yj455",
                 "avatar" => "https://social.heldscal.la/avatar/201.jpeg",
                 "avatar_static" => "https://social.heldscal.la/avatar/s/201.jpeg",
                 "id" => 0
               },
               %{
                 "acct" => other_user.ap_id,
                 "avatar" => "https://social.heldscal.la/avatar/202.jpeg",
                 "avatar_static" => "https://social.heldscal.la/avatar/s/202.jpeg",
                 "id" => other_user.id
               }
             ]
    end
  end

  describe "PUT /api/v1/media/:id" do
    setup do
      actor = insert(:user)

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Object{} = object} =
        ActivityPub.upload(
          file,
          actor: User.ap_id(actor),
          description: "test-m"
        )

      [actor: actor, object: object]
    end

    test "updates name of media", %{conn: conn, actor: actor, object: object} do
      media =
        conn
        |> assign(:user, actor)
        |> put("/api/v1/media/#{object.id}", %{"description" => "test-media"})
        |> json_response(:ok)

      assert media["description"] == "test-media"
      assert refresh_record(object).data["name"] == "test-media"
    end

    test "returns error wheb request is bad", %{conn: conn, actor: actor, object: object} do
      media =
        conn
        |> assign(:user, actor)
        |> put("/api/v1/media/#{object.id}", %{})
        |> json_response(400)

      assert media == %{"error" => "bad_request"}
    end
  end

  describe "DELETE /auth/sign_out" do
    test "redirect to root page", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/auth/sign_out")

      assert conn.status == 302
      assert redirected_to(conn) == "/"
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

  describe "empty_array, stubs for mastodon api" do
    test "GET /api/v1/accounts/:id/identity_proofs", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/#{user.id}/identity_proofs")
        |> json_response(200)

      assert res == []
    end

    test "GET /api/v1/endorsements", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/endorsements")
        |> json_response(200)

      assert res == []
    end

    test "GET /api/v1/trends", %{conn: conn} do
      user = insert(:user)

      res =
        conn
        |> assign(:user, user)
        |> get("/api/v1/trends")
        |> json_response(200)

      assert res == []
    end
  end
end
