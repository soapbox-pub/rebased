# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Ecto.Changeset
  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.FilterView
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Push
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "the home timeline", %{conn: conn} do
    user = insert(:user)
    following = insert(:user)

    {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/timelines/home")

    assert Enum.empty?(json_response(conn, 200))

    {:ok, user} = User.follow(user, following)

    conn =
      build_conn()
      |> assign(:user, user)
      |> get("/api/v1/timelines/home")

    assert [%{"content" => "test"}] = json_response(conn, 200)
  end

  test "the public timeline", %{conn: conn} do
    following = insert(:user)

    capture_log(fn ->
      {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})

      {:ok, [_activity]} =
        OStatus.fetch_activity_from_url("https://shitposter.club/notice/2827873")

      conn =
        conn
        |> get("/api/v1/timelines/public", %{"local" => "False"})

      assert length(json_response(conn, 200)) == 2

      conn =
        build_conn()
        |> get("/api/v1/timelines/public", %{"local" => "True"})

      assert [%{"content" => "test"}] = json_response(conn, 200)

      conn =
        build_conn()
        |> get("/api/v1/timelines/public", %{"local" => "1"})

      assert [%{"content" => "test"}] = json_response(conn, 200)
    end)
  end

  test "the public timeline when public is set to false", %{conn: conn} do
    public = Pleroma.Config.get([:instance, :public])
    Pleroma.Config.put([:instance, :public], false)

    on_exit(fn ->
      Pleroma.Config.put([:instance, :public], public)
    end)

    assert conn
           |> get("/api/v1/timelines/public", %{"local" => "False"})
           |> json_response(403) == %{"error" => "This resource requires authentication."}
  end

  test "posting a status", %{conn: conn} do
    user = insert(:user)

    idempotency_key = "Pikachu rocks!"

    conn_one =
      conn
      |> assign(:user, user)
      |> put_req_header("idempotency-key", idempotency_key)
      |> post("/api/v1/statuses", %{
        "status" => "cofe",
        "spoiler_text" => "2hu",
        "sensitive" => "false"
      })

    {:ok, ttl} = Cachex.ttl(:idempotency_cache, idempotency_key)
    # Six hours
    assert ttl > :timer.seconds(6 * 60 * 60 - 1)

    assert %{"content" => "cofe", "id" => id, "spoiler_text" => "2hu", "sensitive" => false} =
             json_response(conn_one, 200)

    assert Activity.get_by_id(id)

    conn_two =
      conn
      |> assign(:user, user)
      |> put_req_header("idempotency-key", idempotency_key)
      |> post("/api/v1/statuses", %{
        "status" => "cofe",
        "spoiler_text" => "2hu",
        "sensitive" => "false"
      })

    assert %{"id" => second_id} = json_response(conn_two, 200)

    assert id == second_id

    conn_three =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{
        "status" => "cofe",
        "spoiler_text" => "2hu",
        "sensitive" => "false"
      })

    assert %{"id" => third_id} = json_response(conn_three, 200)

    refute id == third_id
  end

  describe "posting polls" do
    test "posting a poll", %{conn: conn} do
      user = insert(:user)
      time = NaiveDateTime.utc_now()

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "Who is the #bestgrill?",
          "poll" => %{"options" => ["Rei", "Asuka", "Misato"], "expires_in" => 420}
        })

      response = json_response(conn, 200)

      assert Enum.all?(response["poll"]["options"], fn %{"title" => title} ->
               title in ["Rei", "Asuka", "Misato"]
             end)

      assert NaiveDateTime.diff(NaiveDateTime.from_iso8601!(response["poll"]["expires_at"]), time) in 420..430
      refute response["poll"]["expred"]
    end

    test "option limit is enforced", %{conn: conn} do
      user = insert(:user)
      limit = Pleroma.Config.get([:instance, :poll_limits, :max_options])

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "desu~",
          "poll" => %{"options" => Enum.map(0..limit, fn _ -> "desu" end), "expires_in" => 1}
        })

      %{"error" => error} = json_response(conn, 422)
      assert error == "Poll can't contain more than #{limit} options"
    end

    test "option character limit is enforced", %{conn: conn} do
      user = insert(:user)
      limit = Pleroma.Config.get([:instance, :poll_limits, :max_option_chars])

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "...",
          "poll" => %{
            "options" => [Enum.reduce(0..limit, "", fn _, acc -> acc <> "." end)],
            "expires_in" => 1
          }
        })

      %{"error" => error} = json_response(conn, 422)
      assert error == "Poll options cannot be longer than #{limit} characters each"
    end

    test "minimal date limit is enforced", %{conn: conn} do
      user = insert(:user)
      limit = Pleroma.Config.get([:instance, :poll_limits, :min_expiration])

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "imagine arbitrary limits",
          "poll" => %{
            "options" => ["this post was made by pleroma gang"],
            "expires_in" => limit - 1
          }
        })

      %{"error" => error} = json_response(conn, 422)
      assert error == "Expiration date is too soon"
    end

    test "maximum date limit is enforced", %{conn: conn} do
      user = insert(:user)
      limit = Pleroma.Config.get([:instance, :poll_limits, :max_expiration])

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "imagine arbitrary limits",
          "poll" => %{
            "options" => ["this post was made by pleroma gang"],
            "expires_in" => limit + 1
          }
        })

      %{"error" => error} = json_response(conn, 422)
      assert error == "Expiration date is too far in the future"
    end
  end

  test "posting a sensitive status", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{"status" => "cofe", "sensitive" => true})

    assert %{"content" => "cofe", "id" => id, "sensitive" => true} = json_response(conn, 200)
    assert Activity.get_by_id(id)
  end

  test "posting a fake status", %{conn: conn} do
    user = insert(:user)

    real_conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{
        "status" =>
          "\"Tenshi Eating a Corndog\" is a much discussed concept on /jp/. The significance of it is disputed, so I will focus on one core concept: the symbolism behind it"
      })

    real_status = json_response(real_conn, 200)

    assert real_status
    assert Object.get_by_ap_id(real_status["uri"])

    real_status =
      real_status
      |> Map.put("id", nil)
      |> Map.put("url", nil)
      |> Map.put("uri", nil)
      |> Map.put("created_at", nil)
      |> Kernel.put_in(["pleroma", "conversation_id"], nil)

    fake_conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{
        "status" =>
          "\"Tenshi Eating a Corndog\" is a much discussed concept on /jp/. The significance of it is disputed, so I will focus on one core concept: the symbolism behind it",
        "preview" => true
      })

    fake_status = json_response(fake_conn, 200)

    assert fake_status
    refute Object.get_by_ap_id(fake_status["uri"])

    fake_status =
      fake_status
      |> Map.put("id", nil)
      |> Map.put("url", nil)
      |> Map.put("uri", nil)
      |> Map.put("created_at", nil)
      |> Kernel.put_in(["pleroma", "conversation_id"], nil)

    assert real_status == fake_status
  end

  test "posting a status with OGP link preview", %{conn: conn} do
    Pleroma.Config.put([:rich_media, :enabled], true)
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{
        "status" => "http://example.com/ogp"
      })

    assert %{"id" => id, "card" => %{"title" => "The Rock"}} = json_response(conn, 200)
    assert Activity.get_by_id(id)
    Pleroma.Config.put([:rich_media, :enabled], false)
  end

  test "posting a direct status", %{conn: conn} do
    user1 = insert(:user)
    user2 = insert(:user)
    content = "direct cofe @#{user2.nickname}"

    conn =
      conn
      |> assign(:user, user1)
      |> post("api/v1/statuses", %{"status" => content, "visibility" => "direct"})

    assert %{"id" => id, "visibility" => "direct"} = json_response(conn, 200)
    assert activity = Activity.get_by_id(id)
    assert activity.recipients == [user2.ap_id, user1.ap_id]
    assert activity.data["to"] == [user2.ap_id]
    assert activity.data["cc"] == []
  end

  test "direct timeline", %{conn: conn} do
    user_one = insert(:user)
    user_two = insert(:user)

    {:ok, user_two} = User.follow(user_two, user_one)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "direct"
      })

    {:ok, _follower_only} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "private"
      })

    # Only direct should be visible here
    res_conn =
      conn
      |> assign(:user, user_two)
      |> get("api/v1/timelines/direct")

    [status] = json_response(res_conn, 200)

    assert %{"visibility" => "direct"} = status
    assert status["url"] != direct.data["id"]

    # User should be able to see his own direct message
    res_conn =
      build_conn()
      |> assign(:user, user_one)
      |> get("api/v1/timelines/direct")

    [status] = json_response(res_conn, 200)

    assert %{"visibility" => "direct"} = status

    # Both should be visible here
    res_conn =
      conn
      |> assign(:user, user_two)
      |> get("api/v1/timelines/home")

    [_s1, _s2] = json_response(res_conn, 200)

    # Test pagination
    Enum.each(1..20, fn _ ->
      {:ok, _} =
        CommonAPI.post(user_one, %{
          "status" => "Hi @#{user_two.nickname}!",
          "visibility" => "direct"
        })
    end)

    res_conn =
      conn
      |> assign(:user, user_two)
      |> get("api/v1/timelines/direct")

    statuses = json_response(res_conn, 200)
    assert length(statuses) == 20

    res_conn =
      conn
      |> assign(:user, user_two)
      |> get("api/v1/timelines/direct", %{max_id: List.last(statuses)["id"]})

    [status] = json_response(res_conn, 200)

    assert status["url"] != direct.data["id"]
  end

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

  test "doesn't include DMs from blocked users", %{conn: conn} do
    blocker = insert(:user)
    blocked = insert(:user)
    user = insert(:user)
    {:ok, blocker} = User.block(blocker, blocked)

    {:ok, _blocked_direct} =
      CommonAPI.post(blocked, %{
        "status" => "Hi @#{blocker.nickname}!",
        "visibility" => "direct"
      })

    {:ok, direct} =
      CommonAPI.post(user, %{
        "status" => "Hi @#{blocker.nickname}!",
        "visibility" => "direct"
      })

    res_conn =
      conn
      |> assign(:user, user)
      |> get("api/v1/timelines/direct")

    [status] = json_response(res_conn, 200)
    assert status["id"] == direct.id
  end

  test "replying to a status", %{conn: conn} do
    user = insert(:user)

    {:ok, replied_to} = TwitterAPI.create_status(user, %{"status" => "cofe"})

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

    assert %{"content" => "xD", "id" => id} = json_response(conn, 200)

    activity = Activity.get_by_id(id)

    assert activity.data["context"] == replied_to.data["context"]
    assert Activity.get_in_reply_to_activity(activity).id == replied_to.id
  end

  test "posting a status with an invalid in_reply_to_id", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => ""})

    assert %{"content" => "xD", "id" => id} = json_response(conn, 200)

    activity = Activity.get_by_id(id)

    assert activity
  end

  test "verify_credentials", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/accounts/verify_credentials")

    assert %{"id" => id, "source" => %{"privacy" => "public"}} = json_response(conn, 200)
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

  test "get a status", %{conn: conn} do
    activity = insert(:note_activity)

    conn =
      conn
      |> get("/api/v1/statuses/#{activity.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(activity.id)
  end

  describe "deleting a status" do
    test "when you created it", %{conn: conn} do
      activity = insert(:note_activity)
      author = User.get_cached_by_ap_id(activity.data["actor"])

      conn =
        conn
        |> assign(:user, author)
        |> delete("/api/v1/statuses/#{activity.id}")

      assert %{} = json_response(conn, 200)

      refute Activity.get_by_id(activity.id)
    end

    test "when you didn't create it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/statuses/#{activity.id}")

      assert %{"error" => _} = json_response(conn, 403)

      assert Activity.get_by_id(activity.id) == activity
    end

    test "when you're an admin or moderator", %{conn: conn} do
      activity1 = insert(:note_activity)
      activity2 = insert(:note_activity)
      admin = insert(:user, info: %{is_admin: true})
      moderator = insert(:user, info: %{is_moderator: true})

      res_conn =
        conn
        |> assign(:user, admin)
        |> delete("/api/v1/statuses/#{activity1.id}")

      assert %{} = json_response(res_conn, 200)

      res_conn =
        conn
        |> assign(:user, moderator)
        |> delete("/api/v1/statuses/#{activity2.id}")

      assert %{} = json_response(res_conn, 200)

      refute Activity.get_by_id(activity1.id)
      refute Activity.get_by_id(activity2.id)
    end
  end

  describe "filters" do
    test "creating a filter", %{conn: conn} do
      user = insert(:user)

      filter = %Pleroma.Filter{
        phrase: "knights",
        context: ["home"]
      }

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/filters", %{"phrase" => filter.phrase, context: filter.context})

      assert response = json_response(conn, 200)
      assert response["phrase"] == filter.phrase
      assert response["context"] == filter.context
      assert response["irreversible"] == false
      assert response["id"] != nil
      assert response["id"] != ""
    end

    test "fetching a list of filters", %{conn: conn} do
      user = insert(:user)

      query_one = %Pleroma.Filter{
        user_id: user.id,
        filter_id: 1,
        phrase: "knights",
        context: ["home"]
      }

      query_two = %Pleroma.Filter{
        user_id: user.id,
        filter_id: 2,
        phrase: "who",
        context: ["home"]
      }

      {:ok, filter_one} = Pleroma.Filter.create(query_one)
      {:ok, filter_two} = Pleroma.Filter.create(query_two)

      response =
        conn
        |> assign(:user, user)
        |> get("/api/v1/filters")
        |> json_response(200)

      assert response ==
               render_json(
                 FilterView,
                 "filters.json",
                 filters: [filter_two, filter_one]
               )
    end

    test "get a filter", %{conn: conn} do
      user = insert(:user)

      query = %Pleroma.Filter{
        user_id: user.id,
        filter_id: 2,
        phrase: "knight",
        context: ["home"]
      }

      {:ok, filter} = Pleroma.Filter.create(query)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/filters/#{filter.filter_id}")

      assert _response = json_response(conn, 200)
    end

    test "update a filter", %{conn: conn} do
      user = insert(:user)

      query = %Pleroma.Filter{
        user_id: user.id,
        filter_id: 2,
        phrase: "knight",
        context: ["home"]
      }

      {:ok, _filter} = Pleroma.Filter.create(query)

      new = %Pleroma.Filter{
        phrase: "nii",
        context: ["home"]
      }

      conn =
        conn
        |> assign(:user, user)
        |> put("/api/v1/filters/#{query.filter_id}", %{
          phrase: new.phrase,
          context: new.context
        })

      assert response = json_response(conn, 200)
      assert response["phrase"] == new.phrase
      assert response["context"] == new.context
    end

    test "delete a filter", %{conn: conn} do
      user = insert(:user)

      query = %Pleroma.Filter{
        user_id: user.id,
        filter_id: 2,
        phrase: "knight",
        context: ["home"]
      }

      {:ok, filter} = Pleroma.Filter.create(query)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/filters/#{filter.filter_id}")

      assert response = json_response(conn, 200)
      assert response == %{}
    end
  end

  describe "lists" do
    test "creating a list", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/lists", %{"title" => "cuties"})

      assert %{"title" => title} = json_response(conn, 200)
      assert title == "cuties"
    end

    test "adding users to a list", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

      assert %{} == json_response(conn, 200)
      %Pleroma.List{following: following} = Pleroma.List.get(list.id, user)
      assert following == [other_user.follower_address]
    end

    test "removing users from a list", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)
      {:ok, list} = Pleroma.List.follow(list, third_user)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

      assert %{} == json_response(conn, 200)
      %Pleroma.List{following: following} = Pleroma.List.get(list.id, user)
      assert following == [third_user.follower_address]
    end

    test "listing users in a list", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

      assert [%{"id" => id}] = json_response(conn, 200)
      assert id == to_string(other_user.id)
    end

    test "retrieving a list", %{conn: conn} do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/lists/#{list.id}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == to_string(list.id)
    end

    test "renaming a list", %{conn: conn} do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)

      conn =
        conn
        |> assign(:user, user)
        |> put("/api/v1/lists/#{list.id}", %{"title" => "newname"})

      assert %{"title" => name} = json_response(conn, 200)
      assert name == "newname"
    end

    test "deleting a list", %{conn: conn} do
      user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/lists/#{list.id}")

      assert %{} = json_response(conn, 200)
      assert is_nil(Repo.get(Pleroma.List, list.id))
    end

    test "list timeline", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, _activity_one} = TwitterAPI.create_status(user, %{"status" => "Marisa is cute."})
      {:ok, activity_two} = TwitterAPI.create_status(other_user, %{"status" => "Marisa is cute."})
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response(conn, 200)

      assert id == to_string(activity_two.id)
    end

    test "list timeline does not leak non-public statuses for unfollowed users", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity_one} = TwitterAPI.create_status(other_user, %{"status" => "Marisa is cute."})

      {:ok, _activity_two} =
        TwitterAPI.create_status(other_user, %{
          "status" => "Marisa is cute.",
          "visibility" => "private"
        })

      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response(conn, 200)

      assert id == to_string(activity_one.id)
    end
  end

  describe "notifications" do
    test "list of notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})

      {:ok, [_notification]} = Notification.create_notifications(activity)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/notifications")

      expected_response =
        "hi <span class=\"h-card\"><a data-user=\"#{user.id}\" class=\"u-url mention\" href=\"#{
          user.ap_id
        }\">@<span>#{user.nickname}</span></a></span>"

      assert [%{"status" => %{"content" => response}} | _rest] = json_response(conn, 200)
      assert response == expected_response
    end

    test "getting a single notification", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/notifications/#{notification.id}")

      expected_response =
        "hi <span class=\"h-card\"><a data-user=\"#{user.id}\" class=\"u-url mention\" href=\"#{
          user.ap_id
        }\">@<span>#{user.nickname}</span></a></span>"

      assert %{"status" => %{"content" => response}} = json_response(conn, 200)
      assert response == expected_response
    end

    test "dismissing a single notification", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})

      {:ok, [notification]} = Notification.create_notifications(activity)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/notifications/dismiss", %{"id" => notification.id})

      assert %{} = json_response(conn, 200)
    end

    test "clearing all notifications", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        TwitterAPI.create_status(other_user, %{"status" => "hi @#{user.nickname}"})

      {:ok, [_notification]} = Notification.create_notifications(activity)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/notifications/clear")

      assert %{} = json_response(conn, 200)

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/notifications")

      assert all = json_response(conn, 200)
      assert all == []
    end

    test "paginates notifications using min_id, since_id, max_id, and limit", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity1} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, activity2} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, activity3} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, activity4} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})

      notification1_id = Repo.get_by(Notification, activity_id: activity1.id).id |> to_string()
      notification2_id = Repo.get_by(Notification, activity_id: activity2.id).id |> to_string()
      notification3_id = Repo.get_by(Notification, activity_id: activity3.id).id |> to_string()
      notification4_id = Repo.get_by(Notification, activity_id: activity4.id).id |> to_string()

      conn =
        conn
        |> assign(:user, user)

      # min_id
      conn_res =
        conn
        |> get("/api/v1/notifications?limit=2&min_id=#{notification1_id}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result

      # since_id
      conn_res =
        conn
        |> get("/api/v1/notifications?limit=2&since_id=#{notification1_id}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result

      # max_id
      conn_res =
        conn
        |> get("/api/v1/notifications?limit=2&max_id=#{notification4_id}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result
    end

    test "filters notifications using exclude_types", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, mention_activity} = CommonAPI.post(other_user, %{"status" => "hey @#{user.nickname}"})
      {:ok, create_activity} = CommonAPI.post(user, %{"status" => "hey"})
      {:ok, favorite_activity, _} = CommonAPI.favorite(create_activity.id, other_user)
      {:ok, reblog_activity, _} = CommonAPI.repeat(create_activity.id, other_user)
      {:ok, _, _, follow_activity} = CommonAPI.follow(other_user, user)

      mention_notification_id =
        Repo.get_by(Notification, activity_id: mention_activity.id).id |> to_string()

      favorite_notification_id =
        Repo.get_by(Notification, activity_id: favorite_activity.id).id |> to_string()

      reblog_notification_id =
        Repo.get_by(Notification, activity_id: reblog_activity.id).id |> to_string()

      follow_notification_id =
        Repo.get_by(Notification, activity_id: follow_activity.id).id |> to_string()

      conn =
        conn
        |> assign(:user, user)

      conn_res =
        get(conn, "/api/v1/notifications", %{exclude_types: ["mention", "favourite", "reblog"]})

      assert [%{"id" => ^follow_notification_id}] = json_response(conn_res, 200)

      conn_res =
        get(conn, "/api/v1/notifications", %{exclude_types: ["favourite", "reblog", "follow"]})

      assert [%{"id" => ^mention_notification_id}] = json_response(conn_res, 200)

      conn_res =
        get(conn, "/api/v1/notifications", %{exclude_types: ["reblog", "follow", "mention"]})

      assert [%{"id" => ^favorite_notification_id}] = json_response(conn_res, 200)

      conn_res =
        get(conn, "/api/v1/notifications", %{exclude_types: ["follow", "mention", "favourite"]})

      assert [%{"id" => ^reblog_notification_id}] = json_response(conn_res, 200)
    end

    test "destroy multiple", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity1} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, activity2} = CommonAPI.post(other_user, %{"status" => "hi @#{user.nickname}"})
      {:ok, activity3} = CommonAPI.post(user, %{"status" => "hi @#{other_user.nickname}"})
      {:ok, activity4} = CommonAPI.post(user, %{"status" => "hi @#{other_user.nickname}"})

      notification1_id = Repo.get_by(Notification, activity_id: activity1.id).id |> to_string()
      notification2_id = Repo.get_by(Notification, activity_id: activity2.id).id |> to_string()
      notification3_id = Repo.get_by(Notification, activity_id: activity3.id).id |> to_string()
      notification4_id = Repo.get_by(Notification, activity_id: activity4.id).id |> to_string()

      conn =
        conn
        |> assign(:user, user)

      conn_res =
        conn
        |> get("/api/v1/notifications")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification2_id}, %{"id" => ^notification1_id}] = result

      conn2 =
        conn
        |> assign(:user, other_user)

      conn_res =
        conn2
        |> get("/api/v1/notifications")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result

      conn_destroy =
        conn
        |> delete("/api/v1/notifications/destroy_multiple", %{
          "ids" => [notification1_id, notification2_id]
        })

      assert json_response(conn_destroy, 200) == %{}

      conn_res =
        conn2
        |> get("/api/v1/notifications")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result
    end
  end

  describe "reblogging" do
    test "reblogs and returns the reblogged status", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses/#{activity.id}/reblog")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1},
               "reblogged" => true
             } = json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "reblogged status for another user", %{conn: conn} do
      activity = insert(:note_activity)
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      CommonAPI.favorite(activity.id, user2)
      {:ok, _bookmark} = Pleroma.Bookmark.create(user2.id, activity.id)
      {:ok, reblog_activity1, _object} = CommonAPI.repeat(activity.id, user1)
      {:ok, _, _object} = CommonAPI.repeat(activity.id, user2)

      conn_res =
        conn
        |> assign(:user, user3)
        |> get("/api/v1/statuses/#{reblog_activity1.id}")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => false, "reblogs_count" => 2},
               "reblogged" => false,
               "favourited" => false,
               "bookmarked" => false
             } = json_response(conn_res, 200)

      conn_res =
        conn
        |> assign(:user, user2)
        |> get("/api/v1/statuses/#{reblog_activity1.id}")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 2},
               "reblogged" => true,
               "favourited" => true,
               "bookmarked" => true
             } = json_response(conn_res, 200)

      assert to_string(activity.id) == id
    end
  end

  describe "unreblogging" do
    test "unreblogs and returns the unreblogged status", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      {:ok, _, _} = CommonAPI.repeat(activity.id, user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses/#{activity.id}/unreblog")

      assert %{"id" => id, "reblogged" => false, "reblogs_count" => 0} = json_response(conn, 200)

      assert to_string(activity.id) == id
    end
  end

  describe "favoriting" do
    test "favs a status and returns it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses/#{activity.id}/favourite")

      assert %{"id" => id, "favourites_count" => 1, "favourited" => true} =
               json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "returns 500 for a wrong id", %{conn: conn} do
      user = insert(:user)

      resp =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses/1/favourite")
        |> json_response(500)

      assert resp == "Something went wrong"
    end
  end

  describe "unfavoriting" do
    test "unfavorites a status and returns it", %{conn: conn} do
      activity = insert(:note_activity)
      user = insert(:user)

      {:ok, _, _} = CommonAPI.favorite(activity.id, user)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses/#{activity.id}/unfavourite")

      assert %{"id" => id, "favourites_count" => 0, "favourited" => false} =
               json_response(conn, 200)

      assert to_string(activity.id) == id
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

      media =
        TwitterAPI.upload(file, user, "json")
        |> Poison.decode!()

      {:ok, image_post} =
        TwitterAPI.create_status(user, %{"status" => "cofe", "media_ids" => [media["media_id"]]})

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
  end

  describe "locked accounts" do
    test "/api/v1/follow_requests works" do
      user = insert(:user, %{info: %User.Info{locked: true}})
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> get("/api/v1/follow_requests")

      assert [relationship] = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]
    end

    test "/api/v1/follow_requests/:id/authorize works" do
      user = insert(:user, %{info: %User.Info{locked: true}})
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/follow_requests/#{other_user.id}/authorize")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == true
    end

    test "verify_credentials", %{conn: conn} do
      user = insert(:user, %{info: %User.Info{default_scope: "private"}})

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/accounts/verify_credentials")

      assert %{"id" => id, "source" => %{"privacy" => "private"}} = json_response(conn, 200)
      assert id == to_string(user.id)
    end

    test "/api/v1/follow_requests/:id/reject works" do
      user = insert(:user, %{info: %User.Info{locked: true}})
      other_user = insert(:user)

      {:ok, _activity} = ActivityPub.follow(other_user, user)

      user = User.get_cached_by_id(user.id)

      conn =
        build_conn()
        |> assign(:user, user)
        |> post("/api/v1/follow_requests/#{other_user.id}/reject")

      assert relationship = json_response(conn, 200)
      assert to_string(other_user.id) == relationship["id"]

      user = User.get_cached_by_id(user.id)
      other_user = User.get_cached_by_id(other_user.id)

      assert User.following?(other_user, user) == false
    end
  end

  test "account fetching", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> get("/api/v1/accounts/#{user.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(user.id)

    conn =
      build_conn()
      |> get("/api/v1/accounts/-1")

    assert %{"error" => "Can't find user"} = json_response(conn, 404)
  end

  test "account fetching also works nickname", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> get("/api/v1/accounts/#{user.nickname}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == user.id
  end

  test "media upload", %{conn: conn} do
    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    desc = "Description of the image"

    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/media", %{"file" => file, "description" => desc})

    assert media = json_response(conn, 200)

    assert media["type"] == "image"
    assert media["description"] == desc
    assert media["id"]

    object = Repo.get(Object, media["id"])
    assert object.data["actor"] == User.ap_id(user)
  end

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

  test "hashtag timeline", %{conn: conn} do
    following = insert(:user)

    capture_log(fn ->
      {:ok, activity} = TwitterAPI.create_status(following, %{"status" => "test #2hu"})

      {:ok, [_activity]} =
        OStatus.fetch_activity_from_url("https://shitposter.club/notice/2827873")

      nconn =
        conn
        |> get("/api/v1/timelines/tag/2hu")

      assert [%{"id" => id}] = json_response(nconn, 200)

      assert id == to_string(activity.id)

      # works for different capitalization too
      nconn =
        conn
        |> get("/api/v1/timelines/tag/2HU")

      assert [%{"id" => id}] = json_response(nconn, 200)

      assert id == to_string(activity.id)
    end)
  end

  test "multi-hashtag timeline", %{conn: conn} do
    user = insert(:user)

    {:ok, activity_test} = CommonAPI.post(user, %{"status" => "#test"})
    {:ok, activity_test1} = CommonAPI.post(user, %{"status" => "#test #test1"})
    {:ok, activity_none} = CommonAPI.post(user, %{"status" => "#test #none"})

    any_test =
      conn
      |> get("/api/v1/timelines/tag/test", %{"any" => ["test1"]})

    [status_none, status_test1, status_test] = json_response(any_test, 200)

    assert to_string(activity_test.id) == status_test["id"]
    assert to_string(activity_test1.id) == status_test1["id"]
    assert to_string(activity_none.id) == status_none["id"]

    restricted_test =
      conn
      |> get("/api/v1/timelines/tag/test", %{"all" => ["test1"], "none" => ["none"]})

    assert [status_test1] == json_response(restricted_test, 200)

    all_test = conn |> get("/api/v1/timelines/tag/test", %{"all" => ["none"]})

    assert [status_none] == json_response(all_test, 200)
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

  test "muting / unmuting a user", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/accounts/#{other_user.id}/mute")

    assert %{"id" => _id, "muting" => true} = json_response(conn, 200)

    user = User.get_cached_by_id(user.id)

    conn =
      build_conn()
      |> assign(:user, user)
      |> post("/api/v1/accounts/#{other_user.id}/unmute")

    assert %{"id" => _id, "muting" => false} = json_response(conn, 200)
  end

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

  test "blocking / unblocking a domain", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user, %{ap_id: "https://dogwhistle.zone/@pundit"})

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/domain_blocks", %{"domain" => "dogwhistle.zone"})

    assert %{} = json_response(conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    assert User.blocks?(user, other_user)

    conn =
      build_conn()
      |> assign(:user, user)
      |> delete("/api/v1/domain_blocks", %{"domain" => "dogwhistle.zone"})

    assert %{} = json_response(conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    refute User.blocks?(user, other_user)
  end

  test "getting a list of domain blocks", %{conn: conn} do
    user = insert(:user)

    {:ok, user} = User.block_domain(user, "bad.site")
    {:ok, user} = User.block_domain(user, "even.worse.site")

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/domain_blocks")

    domain_blocks = json_response(conn, 200)

    assert "bad.site" in domain_blocks
    assert "even.worse.site" in domain_blocks
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

  test "account search", %{conn: conn} do
    user = insert(:user)
    user_two = insert(:user, %{nickname: "shp@shitposter.club"})
    user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

    results =
      conn
      |> assign(:user, user)
      |> get("/api/v1/accounts/search", %{"q" => "shp"})
      |> json_response(200)

    result_ids = for result <- results, do: result["acct"]

    assert user_two.nickname in result_ids
    assert user_three.nickname in result_ids

    results =
      conn
      |> assign(:user, user)
      |> get("/api/v1/accounts/search", %{"q" => "2hu"})
      |> json_response(200)

    result_ids = for result <- results, do: result["acct"]

    assert user_three.nickname in result_ids
  end

  test "search", %{conn: conn} do
    user = insert(:user)
    user_two = insert(:user, %{nickname: "shp@shitposter.club"})
    user_three = insert(:user, %{nickname: "shp@heldscal.la", name: "I love 2hu"})

    {:ok, activity} = CommonAPI.post(user, %{"status" => "This is about 2hu"})

    {:ok, _activity} =
      CommonAPI.post(user, %{
        "status" => "This is about 2hu, but private",
        "visibility" => "private"
      })

    {:ok, _} = CommonAPI.post(user_two, %{"status" => "This isn't"})

    conn =
      conn
      |> get("/api/v1/search", %{"q" => "2hu"})

    assert results = json_response(conn, 200)

    [account | _] = results["accounts"]
    assert account["id"] == to_string(user_three.id)

    assert results["hashtags"] == []

    [status] = results["statuses"]
    assert status["id"] == to_string(activity.id)
  end

  test "search fetches remote statuses", %{conn: conn} do
    capture_log(fn ->
      conn =
        conn
        |> get("/api/v1/search", %{"q" => "https://shitposter.club/notice/2827873"})

      assert results = json_response(conn, 200)

      [status] = results["statuses"]
      assert status["uri"] == "tag:shitposter.club,2017-05-05:noticeId=2827873:objectType=comment"
    end)
  end

  test "search doesn't show statuses that it shouldn't", %{conn: conn} do
    {:ok, activity} =
      CommonAPI.post(insert(:user), %{
        "status" => "This is about 2hu, but private",
        "visibility" => "private"
      })

    capture_log(fn ->
      conn =
        conn
        |> get("/api/v1/search", %{"q" => Object.normalize(activity).data["id"]})

      assert results = json_response(conn, 200)

      [] = results["statuses"]
    end)
  end

  test "search fetches remote accounts", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/search", %{"q" => "shp@social.heldscal.la", "resolve" => "true"})

    assert results = json_response(conn, 200)
    [account] = results["accounts"]
    assert account["acct"] == "shp@social.heldscal.la"
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

  describe "updating credentials" do
    test "sets user settings in a generic way", %{conn: conn} do
      user = insert(:user)

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            pleroma_fe: %{
              theme: "bla"
            }
          }
        })

      assert user = json_response(res_conn, 200)
      assert user["pleroma"]["settings_store"] == %{"pleroma_fe" => %{"theme" => "bla"}}

      user = Repo.get(User, user["id"])

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            masto_fe: %{
              theme: "bla"
            }
          }
        })

      assert user = json_response(res_conn, 200)

      assert user["pleroma"]["settings_store"] ==
               %{
                 "pleroma_fe" => %{"theme" => "bla"},
                 "masto_fe" => %{"theme" => "bla"}
               }

      user = Repo.get(User, user["id"])

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            masto_fe: %{
              theme: "blub"
            }
          }
        })

      assert user = json_response(res_conn, 200)

      assert user["pleroma"]["settings_store"] ==
               %{
                 "pleroma_fe" => %{"theme" => "bla"},
                 "masto_fe" => %{"theme" => "blub"}
               }
    end

    test "updates the user's bio", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "note" => "I drink #cofe with @#{user2.nickname}"
        })

      assert user = json_response(conn, 200)

      assert user["note"] ==
               ~s(I drink <a class="hashtag" data-tag="cofe" href="http://localhost:4001/tag/cofe" rel="tag">#cofe</a> with <span class="h-card"><a data-user=") <>
                 user2.id <>
                 ~s(" class="u-url mention" href=") <>
                 user2.ap_id <> ~s(">@<span>) <> user2.nickname <> ~s(</span></a></span>)
    end

    test "updates the user's locking status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{locked: "true"})

      assert user = json_response(conn, 200)
      assert user["locked"] == true
    end

    test "updates the user's default scope", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{default_scope: "cofe"})

      assert user = json_response(conn, 200)
      assert user["source"]["privacy"] == "cofe"
    end

    test "updates the user's hide_followers status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{hide_followers: "true"})

      assert user = json_response(conn, 200)
      assert user["pleroma"]["hide_followers"] == true
    end

    test "updates the user's skip_thread_containment option", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{skip_thread_containment: "true"})
        |> json_response(200)

      assert response["pleroma"]["skip_thread_containment"] == true
      assert refresh_record(user).info.skip_thread_containment
    end

    test "updates the user's hide_follows status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{hide_follows: "true"})

      assert user = json_response(conn, 200)
      assert user["pleroma"]["hide_follows"] == true
    end

    test "updates the user's hide_favorites status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{hide_favorites: "true"})

      assert user = json_response(conn, 200)
      assert user["pleroma"]["hide_favorites"] == true
    end

    test "updates the user's show_role status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{show_role: "false"})

      assert user = json_response(conn, 200)
      assert user["source"]["pleroma"]["show_role"] == false
    end

    test "updates the user's no_rich_text status", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{no_rich_text: "true"})

      assert user = json_response(conn, 200)
      assert user["source"]["pleroma"]["no_rich_text"] == true
    end

    test "updates the user's name", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{"display_name" => "markorepairs"})

      assert user = json_response(conn, 200)
      assert user["display_name"] == "markorepairs"
    end

    test "updates the user's avatar", %{conn: conn} do
      user = insert(:user)

      new_avatar = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{"avatar" => new_avatar})

      assert user_response = json_response(conn, 200)
      assert user_response["avatar"] != User.avatar_url(user)
    end

    test "updates the user's banner", %{conn: conn} do
      user = insert(:user)

      new_header = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{"header" => new_header})

      assert user_response = json_response(conn, 200)
      assert user_response["header"] != User.banner_url(user)
    end

    test "requires 'write' permission", %{conn: conn} do
      token1 = insert(:oauth_token, scopes: ["read"])
      token2 = insert(:oauth_token, scopes: ["write", "follow"])

      for token <- [token1, token2] do
        conn =
          conn
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> patch("/api/v1/accounts/update_credentials", %{})

        if token == token1 do
          assert %{"error" => "Insufficient permissions: write."} == json_response(conn, 403)
        else
          assert json_response(conn, 200)
        end
      end
    end

    test "updates profile emojos", %{conn: conn} do
      user = insert(:user)

      note = "*sips :blank:*"
      name = "I am :firefox:"

      conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "note" => note,
          "display_name" => name
        })

      assert json_response(conn, 200)

      conn =
        conn
        |> get("/api/v1/accounts/#{user.id}")

      assert user = json_response(conn, 200)

      assert user["note"] == note
      assert user["display_name"] == name
      assert [%{"shortcode" => "blank"}, %{"shortcode" => "firefox"}] = user["emojis"]
    end
  end

  test "get instance information", %{conn: conn} do
    conn = get(conn, "/api/v1/instance")
    assert result = json_response(conn, 200)

    email = Pleroma.Config.get([:instance, :email])
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

    {:ok, _} = TwitterAPI.create_status(user, %{"status" => "cofe"})

    # Stats should count users with missing or nil `info.deactivated` value
    user = User.get_cached_by_id(user.id)
    info_change = Changeset.change(user.info, %{deactivated: nil})

    {:ok, _user} =
      user
      |> Changeset.change()
      |> Changeset.put_embed(:info, info_change)
      |> User.update_and_set_cache()

    Pleroma.Stats.update_stats()

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

    Pleroma.Stats.update_stats()

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
      Pleroma.Config.put([:instance, :max_pinned_statuses], 1)

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

    test "pin status", %{conn: conn, user: user, activity: activity} do
      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "pinned" => true} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/pin")
               |> json_response(200)

      assert [%{"id" => ^id_str, "pinned" => true}] =
               conn
               |> assign(:user, user)
               |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")
               |> json_response(200)
    end

    test "unpin status", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.pin(activity.id, user)

      id_str = to_string(activity.id)
      user = refresh_record(user)

      assert %{"id" => ^id_str, "pinned" => false} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/unpin")
               |> json_response(200)

      assert [] =
               conn
               |> assign(:user, user)
               |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")
               |> json_response(200)
    end

    test "max pinned statuses", %{conn: conn, user: user, activity: activity_one} do
      {:ok, activity_two} = CommonAPI.post(user, %{"status" => "HI!!!"})

      id_str_one = to_string(activity_one.id)

      assert %{"id" => ^id_str_one, "pinned" => true} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{id_str_one}/pin")
               |> json_response(200)

      user = refresh_record(user)

      assert %{"error" => "You have already pinned the maximum number of statuses"} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity_two.id}/pin")
               |> json_response(400)
    end
  end

  describe "cards" do
    setup do
      Pleroma.Config.put([:rich_media, :enabled], true)

      on_exit(fn ->
        Pleroma.Config.put([:rich_media, :enabled], false)
      end)

      user = insert(:user)
      %{user: user}
    end

    test "returns rich-media card", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "http://example.com/ogp"})

      card_data = %{
        "image" => "http://ia.media-imdb.com/images/rock.jpg",
        "provider_name" => "www.imdb.com",
        "provider_url" => "http://www.imdb.com",
        "title" => "The Rock",
        "type" => "link",
        "url" => "http://www.imdb.com/title/tt0117500/",
        "description" =>
          "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
        "pleroma" => %{
          "opengraph" => %{
            "image" => "http://ia.media-imdb.com/images/rock.jpg",
            "title" => "The Rock",
            "type" => "video.movie",
            "url" => "http://www.imdb.com/title/tt0117500/",
            "description" =>
              "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer."
          }
        }
      }

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/card")
        |> json_response(200)

      assert response == card_data

      # works with private posts
      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "http://example.com/ogp", "visibility" => "direct"})

      response_two =
        conn
        |> assign(:user, user)
        |> get("/api/v1/statuses/#{activity.id}/card")
        |> json_response(200)

      assert response_two == card_data
    end

    test "replaces missing description with an empty string", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "http://example.com/ogp-missing-data"})

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/card")
        |> json_response(:ok)

      assert response == %{
               "type" => "link",
               "title" => "Pleroma",
               "description" => "",
               "image" => nil,
               "provider_name" => "pleroma.social",
               "provider_url" => "https://pleroma.social",
               "url" => "https://pleroma.social/",
               "pleroma" => %{
                 "opengraph" => %{
                   "title" => "Pleroma",
                   "type" => "website",
                   "url" => "https://pleroma.social/"
                 }
               }
             }
    end
  end

  test "bookmarks" do
    user = insert(:user)
    for_user = insert(:user)

    {:ok, activity1} =
      CommonAPI.post(user, %{
        "status" => "heweoo?"
      })

    {:ok, activity2} =
      CommonAPI.post(user, %{
        "status" => "heweoo!"
      })

    response1 =
      build_conn()
      |> assign(:user, for_user)
      |> post("/api/v1/statuses/#{activity1.id}/bookmark")

    assert json_response(response1, 200)["bookmarked"] == true

    response2 =
      build_conn()
      |> assign(:user, for_user)
      |> post("/api/v1/statuses/#{activity2.id}/bookmark")

    assert json_response(response2, 200)["bookmarked"] == true

    bookmarks =
      build_conn()
      |> assign(:user, for_user)
      |> get("/api/v1/bookmarks")

    assert [json_response(response2, 200), json_response(response1, 200)] ==
             json_response(bookmarks, 200)

    response1 =
      build_conn()
      |> assign(:user, for_user)
      |> post("/api/v1/statuses/#{activity1.id}/unbookmark")

    assert json_response(response1, 200)["bookmarked"] == false

    bookmarks =
      build_conn()
      |> assign(:user, for_user)
      |> get("/api/v1/bookmarks")

    assert [json_response(response2, 200)] == json_response(bookmarks, 200)
  end

  describe "conversation muting" do
    setup do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "HIE"})

      [user: user, activity: activity]
    end

    test "mute conversation", %{conn: conn, user: user, activity: activity} do
      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "muted" => true} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/mute")
               |> json_response(200)
    end

    test "unmute conversation", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_mute(user, activity)

      id_str = to_string(activity.id)
      user = refresh_record(user)

      assert %{"id" => ^id_str, "muted" => false} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/unmute")
               |> json_response(200)
    end
  end

  describe "reports" do
    setup do
      reporter = insert(:user)
      target_user = insert(:user)

      {:ok, activity} = CommonAPI.post(target_user, %{"status" => "foobar"})

      [reporter: reporter, target_user: target_user, activity: activity]
    end

    test "submit a basic report", %{conn: conn, reporter: reporter, target_user: target_user} do
      assert %{"action_taken" => false, "id" => _} =
               conn
               |> assign(:user, reporter)
               |> post("/api/v1/reports", %{"account_id" => target_user.id})
               |> json_response(200)
    end

    test "submit a report with statuses and comment", %{
      conn: conn,
      reporter: reporter,
      target_user: target_user,
      activity: activity
    } do
      assert %{"action_taken" => false, "id" => _} =
               conn
               |> assign(:user, reporter)
               |> post("/api/v1/reports", %{
                 "account_id" => target_user.id,
                 "status_ids" => [activity.id],
                 "comment" => "bad status!"
               })
               |> json_response(200)
    end

    test "account_id is required", %{
      conn: conn,
      reporter: reporter,
      activity: activity
    } do
      assert %{"error" => "Valid `account_id` required"} =
               conn
               |> assign(:user, reporter)
               |> post("/api/v1/reports", %{"status_ids" => [activity.id]})
               |> json_response(400)
    end

    test "comment must be up to the size specified in the config", %{
      conn: conn,
      reporter: reporter,
      target_user: target_user
    } do
      max_size = Pleroma.Config.get([:instance, :max_report_comment_size], 1000)
      comment = String.pad_trailing("a", max_size + 1, "a")

      error = %{"error" => "Comment must be up to #{max_size} characters"}

      assert ^error =
               conn
               |> assign(:user, reporter)
               |> post("/api/v1/reports", %{"account_id" => target_user.id, "comment" => comment})
               |> json_response(400)
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

  describe "scheduled activities" do
    test "creates a scheduled activity", %{conn: conn} do
      user = insert(:user)
      scheduled_at = NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"scheduled_at" => expected_scheduled_at} = json_response(conn, 200)
      assert expected_scheduled_at == Pleroma.Web.CommonAPI.Utils.to_masto_date(scheduled_at)
      assert [] == Repo.all(Activity)
    end

    test "creates a scheduled activity with a media attachment", %{conn: conn} do
      user = insert(:user)
      scheduled_at = NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "media_ids" => [to_string(upload.id)],
          "status" => "scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"media_attachments" => [media_attachment]} = json_response(conn, 200)
      assert %{"type" => "image"} = media_attachment
    end

    test "skips the scheduling and creates the activity if scheduled_at is earlier than 5 minutes from now",
         %{conn: conn} do
      user = insert(:user)

      scheduled_at =
        NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(5) - 1, :millisecond)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{
          "status" => "not scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"content" => "not scheduled"} = json_response(conn, 200)
      assert [] == Repo.all(ScheduledActivity)
    end

    test "returns error when daily user limit is exceeded", %{conn: conn} do
      user = insert(:user)

      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: today}
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:ok, _} = ScheduledActivity.create(user, attrs)

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{"status" => "scheduled", "scheduled_at" => today})

      assert %{"error" => "daily limit exceeded"} == json_response(conn, 422)
    end

    test "returns error when total user limit is exceeded", %{conn: conn} do
      user = insert(:user)

      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      tomorrow =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.hours(36), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: today}
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:ok, _} = ScheduledActivity.create(user, %{params: %{}, scheduled_at: tomorrow})

      conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/statuses", %{"status" => "scheduled", "scheduled_at" => tomorrow})

      assert %{"error" => "total limit exceeded"} == json_response(conn, 422)
    end

    test "shows scheduled activities", %{conn: conn} do
      user = insert(:user)
      scheduled_activity_id1 = insert(:scheduled_activity, user: user).id |> to_string()
      scheduled_activity_id2 = insert(:scheduled_activity, user: user).id |> to_string()
      scheduled_activity_id3 = insert(:scheduled_activity, user: user).id |> to_string()
      scheduled_activity_id4 = insert(:scheduled_activity, user: user).id |> to_string()

      conn =
        conn
        |> assign(:user, user)

      # min_id
      conn_res =
        conn
        |> get("/api/v1/scheduled_statuses?limit=2&min_id=#{scheduled_activity_id1}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result

      # since_id
      conn_res =
        conn
        |> get("/api/v1/scheduled_statuses?limit=2&since_id=#{scheduled_activity_id1}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^scheduled_activity_id4}, %{"id" => ^scheduled_activity_id3}] = result

      # max_id
      conn_res =
        conn
        |> get("/api/v1/scheduled_statuses?limit=2&max_id=#{scheduled_activity_id4}")

      result = json_response(conn_res, 200)
      assert [%{"id" => ^scheduled_activity_id3}, %{"id" => ^scheduled_activity_id2}] = result
    end

    test "shows a scheduled activity", %{conn: conn} do
      user = insert(:user)
      scheduled_activity = insert(:scheduled_activity, user: user)

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

      assert %{"id" => scheduled_activity_id} = json_response(res_conn, 200)
      assert scheduled_activity_id == scheduled_activity.id |> to_string()

      res_conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/scheduled_statuses/404")

      assert %{"error" => "Record not found"} = json_response(res_conn, 404)
    end

    test "updates a scheduled activity", %{conn: conn} do
      user = insert(:user)
      scheduled_activity = insert(:scheduled_activity, user: user)

      new_scheduled_at =
        NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

      res_conn =
        conn
        |> assign(:user, user)
        |> put("/api/v1/scheduled_statuses/#{scheduled_activity.id}", %{
          scheduled_at: new_scheduled_at
        })

      assert %{"scheduled_at" => expected_scheduled_at} = json_response(res_conn, 200)
      assert expected_scheduled_at == Pleroma.Web.CommonAPI.Utils.to_masto_date(new_scheduled_at)

      res_conn =
        conn
        |> assign(:user, user)
        |> put("/api/v1/scheduled_statuses/404", %{scheduled_at: new_scheduled_at})

      assert %{"error" => "Record not found"} = json_response(res_conn, 404)
    end

    test "deletes a scheduled activity", %{conn: conn} do
      user = insert(:user)
      scheduled_activity = insert(:scheduled_activity, user: user)

      res_conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

      assert %{} = json_response(res_conn, 200)
      assert nil == Repo.get(ScheduledActivity, scheduled_activity.id)

      res_conn =
        conn
        |> assign(:user, user)
        |> delete("/api/v1/scheduled_statuses/#{scheduled_activity.id}")

      assert %{"error" => "Record not found"} = json_response(res_conn, 404)
    end
  end

  test "Repeated posts that are replies incorrectly have in_reply_to_id null", %{conn: conn} do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)

    {:ok, replied_to} = TwitterAPI.create_status(user1, %{"status" => "cofe"})

    # Reply to status from another user
    conn1 =
      conn
      |> assign(:user, user2)
      |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

    assert %{"content" => "xD", "id" => id} = json_response(conn1, 200)

    activity = Activity.get_by_id_with_object(id)

    assert Object.normalize(activity).data["inReplyTo"] == Object.normalize(replied_to).data["id"]
    assert Activity.get_in_reply_to_activity(activity).id == replied_to.id

    # Reblog from the third user
    conn2 =
      conn
      |> assign(:user, user3)
      |> post("/api/v1/statuses/#{activity.id}/reblog")

    assert %{"reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1}} =
             json_response(conn2, 200)

    assert to_string(activity.id) == id

    # Getting third user status
    conn3 =
      conn
      |> assign(:user, user3)
      |> get("api/v1/timelines/home")

    [reblogged_activity] = json_response(conn3, 200)

    assert reblogged_activity["reblog"]["in_reply_to_id"] == replied_to.id

    replied_to_user = User.get_by_ap_id(replied_to.data["actor"])
    assert reblogged_activity["reblog"]["in_reply_to_account_id"] == replied_to_user.id
  end

  describe "create account by app" do
    setup do
      enabled = Pleroma.Config.get([:app_account_creation, :enabled])
      max_requests = Pleroma.Config.get([:app_account_creation, :max_requests])
      interval = Pleroma.Config.get([:app_account_creation, :interval])

      Pleroma.Config.put([:app_account_creation, :enabled], true)
      Pleroma.Config.put([:app_account_creation, :max_requests], 5)
      Pleroma.Config.put([:app_account_creation, :interval], 1)

      on_exit(fn ->
        Pleroma.Config.put([:app_account_creation, :enabled], enabled)
        Pleroma.Config.put([:app_account_creation, :max_requests], max_requests)
        Pleroma.Config.put([:app_account_creation, :interval], interval)
      end)

      :ok
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

      assert json_response(conn, 403) == %{"error" => "Rate limit exceeded."}
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
      id = object.id
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
  end
end
