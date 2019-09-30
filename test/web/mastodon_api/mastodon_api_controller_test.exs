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
  alias Pleroma.Web.Push

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Swoosh.TestAssertions
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance, :public])
  clear_config([:rich_media, :enabled])

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
