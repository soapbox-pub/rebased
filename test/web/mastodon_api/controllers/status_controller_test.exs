# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Config
  alias Pleroma.Conversation.Participation
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  clear_config([:instance, :federating])
  clear_config([:instance, :allow_relay])

  describe "posting statuses" do
    setup do: oauth_access(["write:statuses"])

    test "posting a status does not increment reblog_count when relaying", %{conn: conn} do
      Pleroma.Config.put([:instance, :federating], true)
      Pleroma.Config.get([:instance, :allow_relay], true)

      response =
        conn
        |> post("api/v1/statuses", %{
          "content_type" => "text/plain",
          "source" => "Pleroma FE",
          "status" => "Hello world",
          "visibility" => "public"
        })
        |> json_response(200)

      assert response["reblogs_count"] == 0
      ObanHelpers.perform_all()

      response =
        conn
        |> get("api/v1/statuses/#{response["id"]}", %{})
        |> json_response(200)

      assert response["reblogs_count"] == 0
    end

    test "posting a status", %{conn: conn} do
      idempotency_key = "Pikachu rocks!"

      conn_one =
        conn
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
        |> post("/api/v1/statuses", %{
          "status" => "cofe",
          "spoiler_text" => "2hu",
          "sensitive" => "false"
        })

      assert %{"id" => third_id} = json_response(conn_three, 200)
      refute id == third_id

      # An activity that will expire:
      # 2 hours
      expires_in = 120 * 60

      conn_four =
        conn
        |> post("api/v1/statuses", %{
          "status" => "oolong",
          "expires_in" => expires_in
        })

      assert fourth_response = %{"id" => fourth_id} = json_response(conn_four, 200)
      assert activity = Activity.get_by_id(fourth_id)
      assert expiration = ActivityExpiration.get_by_activity_id(fourth_id)

      estimated_expires_at =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(expires_in)
        |> NaiveDateTime.truncate(:second)

      # This assert will fail if the test takes longer than a minute. I sure hope it never does:
      assert abs(NaiveDateTime.diff(expiration.scheduled_at, estimated_expires_at, :second)) < 60

      assert fourth_response["pleroma"]["expires_at"] ==
               NaiveDateTime.to_iso8601(expiration.scheduled_at)
    end

    test "it fails to create a status if `expires_in` is less or equal than an hour", %{
      conn: conn
    } do
      # 1 hour
      expires_in = 60 * 60

      assert %{"error" => "Expiry date is too soon"} =
               conn
               |> post("api/v1/statuses", %{
                 "status" => "oolong",
                 "expires_in" => expires_in
               })
               |> json_response(422)

      # 30 minutes
      expires_in = 30 * 60

      assert %{"error" => "Expiry date is too soon"} =
               conn
               |> post("api/v1/statuses", %{
                 "status" => "oolong",
                 "expires_in" => expires_in
               })
               |> json_response(422)
    end

    test "posting an undefined status with an attachment", %{user: user, conn: conn} do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      conn =
        post(conn, "/api/v1/statuses", %{
          "media_ids" => [to_string(upload.id)]
        })

      assert json_response(conn, 200)
    end

    test "replying to a status", %{user: user, conn: conn} do
      {:ok, replied_to} = CommonAPI.post(user, %{"status" => "cofe"})

      conn =
        conn
        |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

      assert %{"content" => "xD", "id" => id} = json_response(conn, 200)

      activity = Activity.get_by_id(id)

      assert activity.data["context"] == replied_to.data["context"]
      assert Activity.get_in_reply_to_activity(activity).id == replied_to.id
    end

    test "replying to a direct message with visibility other than direct", %{
      user: user,
      conn: conn
    } do
      {:ok, replied_to} = CommonAPI.post(user, %{"status" => "suya..", "visibility" => "direct"})

      Enum.each(["public", "private", "unlisted"], fn visibility ->
        conn =
          conn
          |> post("/api/v1/statuses", %{
            "status" => "@#{user.nickname} hey",
            "in_reply_to_id" => replied_to.id,
            "visibility" => visibility
          })

        assert json_response(conn, 422) == %{"error" => "The message visibility must be direct"}
      end)
    end

    test "posting a status with an invalid in_reply_to_id", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => ""})

      assert %{"content" => "xD", "id" => id} = json_response(conn, 200)
      assert Activity.get_by_id(id)
    end

    test "posting a sensitive status", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses", %{"status" => "cofe", "sensitive" => true})

      assert %{"content" => "cofe", "id" => id, "sensitive" => true} = json_response(conn, 200)
      assert Activity.get_by_id(id)
    end

    test "posting a fake status", %{conn: conn} do
      real_conn =
        post(conn, "/api/v1/statuses", %{
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
        post(conn, "/api/v1/statuses", %{
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
      Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
      Config.put([:rich_media, :enabled], true)

      conn =
        post(conn, "/api/v1/statuses", %{
          "status" => "https://example.com/ogp"
        })

      assert %{"id" => id, "card" => %{"title" => "The Rock"}} = json_response(conn, 200)
      assert Activity.get_by_id(id)
    end

    test "posting a direct status", %{conn: conn} do
      user2 = insert(:user)
      content = "direct cofe @#{user2.nickname}"

      conn = post(conn, "api/v1/statuses", %{"status" => content, "visibility" => "direct"})

      assert %{"id" => id} = response = json_response(conn, 200)
      assert response["visibility"] == "direct"
      assert response["pleroma"]["direct_conversation_id"]
      assert activity = Activity.get_by_id(id)
      assert activity.recipients == [user2.ap_id, conn.assigns[:user].ap_id]
      assert activity.data["to"] == [user2.ap_id]
      assert activity.data["cc"] == []
    end
  end

  describe "posting scheduled statuses" do
    setup do: oauth_access(["write:statuses"])

    test "creates a scheduled activity", %{conn: conn} do
      scheduled_at = NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

      conn =
        post(conn, "/api/v1/statuses", %{
          "status" => "scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"scheduled_at" => expected_scheduled_at} = json_response(conn, 200)
      assert expected_scheduled_at == CommonAPI.Utils.to_masto_date(scheduled_at)
      assert [] == Repo.all(Activity)
    end

    test "creates a scheduled activity with a media attachment", %{user: user, conn: conn} do
      scheduled_at = NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(120), :millisecond)

      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      conn =
        post(conn, "/api/v1/statuses", %{
          "media_ids" => [to_string(upload.id)],
          "status" => "scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"media_attachments" => [media_attachment]} = json_response(conn, 200)
      assert %{"type" => "image"} = media_attachment
    end

    test "skips the scheduling and creates the activity if scheduled_at is earlier than 5 minutes from now",
         %{conn: conn} do
      scheduled_at =
        NaiveDateTime.add(NaiveDateTime.utc_now(), :timer.minutes(5) - 1, :millisecond)

      conn =
        post(conn, "/api/v1/statuses", %{
          "status" => "not scheduled",
          "scheduled_at" => scheduled_at
        })

      assert %{"content" => "not scheduled"} = json_response(conn, 200)
      assert [] == Repo.all(ScheduledActivity)
    end

    test "returns error when daily user limit is exceeded", %{user: user, conn: conn} do
      today =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(:timer.minutes(6), :millisecond)
        |> NaiveDateTime.to_iso8601()

      attrs = %{params: %{}, scheduled_at: today}
      {:ok, _} = ScheduledActivity.create(user, attrs)
      {:ok, _} = ScheduledActivity.create(user, attrs)

      conn = post(conn, "/api/v1/statuses", %{"status" => "scheduled", "scheduled_at" => today})

      assert %{"error" => "daily limit exceeded"} == json_response(conn, 422)
    end

    test "returns error when total user limit is exceeded", %{user: user, conn: conn} do
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
        post(conn, "/api/v1/statuses", %{"status" => "scheduled", "scheduled_at" => tomorrow})

      assert %{"error" => "total limit exceeded"} == json_response(conn, 422)
    end
  end

  describe "posting polls" do
    setup do: oauth_access(["write:statuses"])

    test "posting a poll", %{conn: conn} do
      time = NaiveDateTime.utc_now()

      conn =
        post(conn, "/api/v1/statuses", %{
          "status" => "Who is the #bestgrill?",
          "poll" => %{"options" => ["Rei", "Asuka", "Misato"], "expires_in" => 420}
        })

      response = json_response(conn, 200)

      assert Enum.all?(response["poll"]["options"], fn %{"title" => title} ->
               title in ["Rei", "Asuka", "Misato"]
             end)

      assert NaiveDateTime.diff(NaiveDateTime.from_iso8601!(response["poll"]["expires_at"]), time) in 420..430
      refute response["poll"]["expred"]

      question = Object.get_by_id(response["poll"]["id"])

      # closed contains utc timezone
      assert question.data["closed"] =~ "Z"
    end

    test "option limit is enforced", %{conn: conn} do
      limit = Config.get([:instance, :poll_limits, :max_options])

      conn =
        post(conn, "/api/v1/statuses", %{
          "status" => "desu~",
          "poll" => %{"options" => Enum.map(0..limit, fn _ -> "desu" end), "expires_in" => 1}
        })

      %{"error" => error} = json_response(conn, 422)
      assert error == "Poll can't contain more than #{limit} options"
    end

    test "option character limit is enforced", %{conn: conn} do
      limit = Config.get([:instance, :poll_limits, :max_option_chars])

      conn =
        post(conn, "/api/v1/statuses", %{
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
      limit = Config.get([:instance, :poll_limits, :min_expiration])

      conn =
        post(conn, "/api/v1/statuses", %{
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
      limit = Config.get([:instance, :poll_limits, :max_expiration])

      conn =
        post(conn, "/api/v1/statuses", %{
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

  test "get a status" do
    %{conn: conn} = oauth_access(["read:statuses"])
    activity = insert(:note_activity)

    conn = get(conn, "/api/v1/statuses/#{activity.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(activity.id)
  end

  test "get a direct status" do
    %{user: user, conn: conn} = oauth_access(["read:statuses"])
    other_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "@#{other_user.nickname}", "visibility" => "direct"})

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/statuses/#{activity.id}")

    [participation] = Participation.for_user(user)

    res = json_response(conn, 200)
    assert res["pleroma"]["direct_conversation_id"] == participation.id
  end

  test "get statuses by IDs" do
    %{conn: conn} = oauth_access(["read:statuses"])
    %{id: id1} = insert(:note_activity)
    %{id: id2} = insert(:note_activity)

    query_string = "ids[]=#{id1}&ids[]=#{id2}"
    conn = get(conn, "/api/v1/statuses/?#{query_string}")

    assert [%{"id" => ^id1}, %{"id" => ^id2}] = Enum.sort_by(json_response(conn, :ok), & &1["id"])
  end

  describe "deleting a status" do
    test "when you created it" do
      %{user: author, conn: conn} = oauth_access(["write:statuses"])
      activity = insert(:note_activity, user: author)

      conn =
        conn
        |> assign(:user, author)
        |> delete("/api/v1/statuses/#{activity.id}")

      assert %{} = json_response(conn, 200)

      refute Activity.get_by_id(activity.id)
    end

    test "when you didn't create it" do
      %{conn: conn} = oauth_access(["write:statuses"])
      activity = insert(:note_activity)

      conn = delete(conn, "/api/v1/statuses/#{activity.id}")

      assert %{"error" => _} = json_response(conn, 403)

      assert Activity.get_by_id(activity.id) == activity
    end

    test "when you're an admin or moderator", %{conn: conn} do
      activity1 = insert(:note_activity)
      activity2 = insert(:note_activity)
      admin = insert(:user, is_admin: true)
      moderator = insert(:user, is_moderator: true)

      res_conn =
        conn
        |> assign(:user, admin)
        |> assign(:token, insert(:oauth_token, user: admin, scopes: ["write:statuses"]))
        |> delete("/api/v1/statuses/#{activity1.id}")

      assert %{} = json_response(res_conn, 200)

      res_conn =
        conn
        |> assign(:user, moderator)
        |> assign(:token, insert(:oauth_token, user: moderator, scopes: ["write:statuses"]))
        |> delete("/api/v1/statuses/#{activity2.id}")

      assert %{} = json_response(res_conn, 200)

      refute Activity.get_by_id(activity1.id)
      refute Activity.get_by_id(activity2.id)
    end
  end

  describe "reblogging" do
    setup do: oauth_access(["write:statuses"])

    test "reblogs and returns the reblogged status", %{conn: conn} do
      activity = insert(:note_activity)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/reblog")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1},
               "reblogged" => true
             } = json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "reblogs privately and returns the reblogged status", %{conn: conn} do
      activity = insert(:note_activity)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/reblog", %{"visibility" => "private"})

      assert %{
               "reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1},
               "reblogged" => true,
               "visibility" => "private"
             } = json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "reblogged status for another user" do
      activity = insert(:note_activity)
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      CommonAPI.favorite(activity.id, user2)
      {:ok, _bookmark} = Pleroma.Bookmark.create(user2.id, activity.id)
      {:ok, reblog_activity1, _object} = CommonAPI.repeat(activity.id, user1)
      {:ok, _, _object} = CommonAPI.repeat(activity.id, user2)

      conn_res =
        build_conn()
        |> assign(:user, user3)
        |> assign(:token, insert(:oauth_token, user: user3, scopes: ["read:statuses"]))
        |> get("/api/v1/statuses/#{reblog_activity1.id}")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => false, "reblogs_count" => 2},
               "reblogged" => false,
               "favourited" => false,
               "bookmarked" => false
             } = json_response(conn_res, 200)

      conn_res =
        build_conn()
        |> assign(:user, user2)
        |> assign(:token, insert(:oauth_token, user: user2, scopes: ["read:statuses"]))
        |> get("/api/v1/statuses/#{reblog_activity1.id}")

      assert %{
               "reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 2},
               "reblogged" => true,
               "favourited" => true,
               "bookmarked" => true
             } = json_response(conn_res, 200)

      assert to_string(activity.id) == id
    end

    test "returns 400 error when activity is not exist", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses/foo/reblog")

      assert json_response(conn, 400) == %{"error" => "Could not repeat"}
    end
  end

  describe "unreblogging" do
    setup do: oauth_access(["write:statuses"])

    test "unreblogs and returns the unreblogged status", %{user: user, conn: conn} do
      activity = insert(:note_activity)

      {:ok, _, _} = CommonAPI.repeat(activity.id, user)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/unreblog")

      assert %{"id" => id, "reblogged" => false, "reblogs_count" => 0} = json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "returns 400 error when activity is not exist", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses/foo/unreblog")

      assert json_response(conn, 400) == %{"error" => "Could not unrepeat"}
    end
  end

  describe "favoriting" do
    setup do: oauth_access(["write:favourites"])

    test "favs a status and returns it", %{conn: conn} do
      activity = insert(:note_activity)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/favourite")

      assert %{"id" => id, "favourites_count" => 1, "favourited" => true} =
               json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "favoriting twice will just return 200", %{conn: conn} do
      activity = insert(:note_activity)

      post(conn, "/api/v1/statuses/#{activity.id}/favourite")
      assert post(conn, "/api/v1/statuses/#{activity.id}/favourite") |> json_response(200)
    end

    test "returns 400 error for a wrong id", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses/1/favourite")

      assert json_response(conn, 400) == %{"error" => "Could not favorite"}
    end
  end

  describe "unfavoriting" do
    setup do: oauth_access(["write:favourites"])

    test "unfavorites a status and returns it", %{user: user, conn: conn} do
      activity = insert(:note_activity)

      {:ok, _, _} = CommonAPI.favorite(activity.id, user)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/unfavourite")

      assert %{"id" => id, "favourites_count" => 0, "favourited" => false} =
               json_response(conn, 200)

      assert to_string(activity.id) == id
    end

    test "returns 400 error for a wrong id", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses/1/unfavourite")

      assert json_response(conn, 400) == %{"error" => "Could not unfavorite"}
    end
  end

  describe "pinned statuses" do
    setup do: oauth_access(["write:accounts"])

    setup %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "HI!!!"})

      %{activity: activity}
    end

    clear_config([:instance, :max_pinned_statuses]) do
      Config.put([:instance, :max_pinned_statuses], 1)
    end

    test "pin status", %{conn: conn, user: user, activity: activity} do
      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "pinned" => true} =
               conn
               |> post("/api/v1/statuses/#{activity.id}/pin")
               |> json_response(200)

      assert [%{"id" => ^id_str, "pinned" => true}] =
               conn
               |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")
               |> json_response(200)
    end

    test "/pin: returns 400 error when activity is not public", %{conn: conn, user: user} do
      {:ok, dm} = CommonAPI.post(user, %{"status" => "test", "visibility" => "direct"})

      conn = post(conn, "/api/v1/statuses/#{dm.id}/pin")

      assert json_response(conn, 400) == %{"error" => "Could not pin"}
    end

    test "unpin status", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.pin(activity.id, user)
      user = refresh_record(user)

      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "pinned" => false} =
               conn
               |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/unpin")
               |> json_response(200)

      assert [] =
               conn
               |> get("/api/v1/accounts/#{user.id}/statuses?pinned=true")
               |> json_response(200)
    end

    test "/unpin: returns 400 error when activity is not exist", %{conn: conn} do
      conn = post(conn, "/api/v1/statuses/1/unpin")

      assert json_response(conn, 400) == %{"error" => "Could not unpin"}
    end

    test "max pinned statuses", %{conn: conn, user: user, activity: activity_one} do
      {:ok, activity_two} = CommonAPI.post(user, %{"status" => "HI!!!"})

      id_str_one = to_string(activity_one.id)

      assert %{"id" => ^id_str_one, "pinned" => true} =
               conn
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
      Config.put([:rich_media, :enabled], true)

      oauth_access(["read:statuses"])
    end

    test "returns rich-media card", %{conn: conn, user: user} do
      Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "https://example.com/ogp"})

      card_data = %{
        "image" => "http://ia.media-imdb.com/images/rock.jpg",
        "provider_name" => "example.com",
        "provider_url" => "https://example.com",
        "title" => "The Rock",
        "type" => "link",
        "url" => "https://example.com/ogp",
        "description" =>
          "Directed by Michael Bay. With Sean Connery, Nicolas Cage, Ed Harris, John Spencer.",
        "pleroma" => %{
          "opengraph" => %{
            "image" => "http://ia.media-imdb.com/images/rock.jpg",
            "title" => "The Rock",
            "type" => "video.movie",
            "url" => "https://example.com/ogp",
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
        CommonAPI.post(user, %{"status" => "https://example.com/ogp", "visibility" => "direct"})

      response_two =
        conn
        |> get("/api/v1/statuses/#{activity.id}/card")
        |> json_response(200)

      assert response_two == card_data
    end

    test "replaces missing description with an empty string", %{conn: conn, user: user} do
      Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

      {:ok, activity} =
        CommonAPI.post(user, %{"status" => "https://example.com/ogp-missing-data"})

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/card")
        |> json_response(:ok)

      assert response == %{
               "type" => "link",
               "title" => "Pleroma",
               "description" => "",
               "image" => nil,
               "provider_name" => "example.com",
               "provider_url" => "https://example.com",
               "url" => "https://example.com/ogp-missing-data",
               "pleroma" => %{
                 "opengraph" => %{
                   "title" => "Pleroma",
                   "type" => "website",
                   "url" => "https://example.com/ogp-missing-data"
                 }
               }
             }
    end
  end

  test "bookmarks" do
    %{conn: conn} = oauth_access(["write:bookmarks", "read:bookmarks"])
    author = insert(:user)

    {:ok, activity1} =
      CommonAPI.post(author, %{
        "status" => "heweoo?"
      })

    {:ok, activity2} =
      CommonAPI.post(author, %{
        "status" => "heweoo!"
      })

    response1 = post(conn, "/api/v1/statuses/#{activity1.id}/bookmark")

    assert json_response(response1, 200)["bookmarked"] == true

    response2 = post(conn, "/api/v1/statuses/#{activity2.id}/bookmark")

    assert json_response(response2, 200)["bookmarked"] == true

    bookmarks = get(conn, "/api/v1/bookmarks")

    assert [json_response(response2, 200), json_response(response1, 200)] ==
             json_response(bookmarks, 200)

    response1 = post(conn, "/api/v1/statuses/#{activity1.id}/unbookmark")

    assert json_response(response1, 200)["bookmarked"] == false

    bookmarks = get(conn, "/api/v1/bookmarks")

    assert [json_response(response2, 200)] == json_response(bookmarks, 200)
  end

  describe "conversation muting" do
    setup do: oauth_access(["write:mutes"])

    setup do
      post_user = insert(:user)
      {:ok, activity} = CommonAPI.post(post_user, %{"status" => "HIE"})
      %{activity: activity}
    end

    test "mute conversation", %{conn: conn, activity: activity} do
      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "muted" => true} =
               conn
               |> post("/api/v1/statuses/#{activity.id}/mute")
               |> json_response(200)
    end

    test "cannot mute already muted conversation", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_mute(user, activity)

      conn = post(conn, "/api/v1/statuses/#{activity.id}/mute")

      assert json_response(conn, 400) == %{"error" => "conversation is already muted"}
    end

    test "unmute conversation", %{conn: conn, user: user, activity: activity} do
      {:ok, _} = CommonAPI.add_mute(user, activity)

      id_str = to_string(activity.id)

      assert %{"id" => ^id_str, "muted" => false} =
               conn
               # |> assign(:user, user)
               |> post("/api/v1/statuses/#{activity.id}/unmute")
               |> json_response(200)
    end
  end

  test "Repeated posts that are replies incorrectly have in_reply_to_id null", %{conn: conn} do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)

    {:ok, replied_to} = CommonAPI.post(user1, %{"status" => "cofe"})

    # Reply to status from another user
    conn1 =
      conn
      |> assign(:user, user2)
      |> assign(:token, insert(:oauth_token, user: user2, scopes: ["write:statuses"]))
      |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

    assert %{"content" => "xD", "id" => id} = json_response(conn1, 200)

    activity = Activity.get_by_id_with_object(id)

    assert Object.normalize(activity).data["inReplyTo"] == Object.normalize(replied_to).data["id"]
    assert Activity.get_in_reply_to_activity(activity).id == replied_to.id

    # Reblog from the third user
    conn2 =
      conn
      |> assign(:user, user3)
      |> assign(:token, insert(:oauth_token, user: user3, scopes: ["write:statuses"]))
      |> post("/api/v1/statuses/#{activity.id}/reblog")

    assert %{"reblog" => %{"id" => id, "reblogged" => true, "reblogs_count" => 1}} =
             json_response(conn2, 200)

    assert to_string(activity.id) == id

    # Getting third user status
    conn3 =
      conn
      |> assign(:user, user3)
      |> assign(:token, insert(:oauth_token, user: user3, scopes: ["read:statuses"]))
      |> get("api/v1/timelines/home")

    [reblogged_activity] = json_response(conn3, 200)

    assert reblogged_activity["reblog"]["in_reply_to_id"] == replied_to.id

    replied_to_user = User.get_by_ap_id(replied_to.data["actor"])
    assert reblogged_activity["reblog"]["in_reply_to_account_id"] == replied_to_user.id
  end

  describe "GET /api/v1/statuses/:id/favourited_by" do
    setup do: oauth_access(["read:accounts"])

    setup %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "test"})

      %{activity: activity}
    end

    test "returns users who have favorited the status", %{conn: conn, activity: activity} do
      other_user = insert(:user)
      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/favourited_by")
        |> json_response(:ok)

      [%{"id" => id}] = response

      assert id == other_user.id
    end

    test "returns empty array when status has not been favorited yet", %{
      conn: conn,
      activity: activity
    } do
      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/favourited_by")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "does not return users who have favorited the status but are blocked", %{
      conn: %{assigns: %{user: user}} = conn,
      activity: activity
    } do
      other_user = insert(:user)
      {:ok, _user_relationship} = User.block(user, other_user)

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/favourited_by")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "does not fail on an unauthenticated request", %{activity: activity} do
      other_user = insert(:user)
      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      response =
        build_conn()
        |> get("/api/v1/statuses/#{activity.id}/favourited_by")
        |> json_response(:ok)

      [%{"id" => id}] = response
      assert id == other_user.id
    end

    test "requires authentication for private posts", %{user: user} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "@#{other_user.nickname} wanna get some #cofe together?",
          "visibility" => "direct"
        })

      {:ok, _, _} = CommonAPI.favorite(activity.id, other_user)

      favourited_by_url = "/api/v1/statuses/#{activity.id}/favourited_by"

      build_conn()
      |> get(favourited_by_url)
      |> json_response(404)

      conn =
        build_conn()
        |> assign(:user, other_user)
        |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["read:accounts"]))

      conn
      |> assign(:token, nil)
      |> get(favourited_by_url)
      |> json_response(404)

      response =
        conn
        |> get(favourited_by_url)
        |> json_response(200)

      [%{"id" => id}] = response
      assert id == other_user.id
    end
  end

  describe "GET /api/v1/statuses/:id/reblogged_by" do
    setup do: oauth_access(["read:accounts"])

    setup %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{"status" => "test"})

      %{activity: activity}
    end

    test "returns users who have reblogged the status", %{conn: conn, activity: activity} do
      other_user = insert(:user)
      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(:ok)

      [%{"id" => id}] = response

      assert id == other_user.id
    end

    test "returns empty array when status has not been reblogged yet", %{
      conn: conn,
      activity: activity
    } do
      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "does not return users who have reblogged the status but are blocked", %{
      conn: %{assigns: %{user: user}} = conn,
      activity: activity
    } do
      other_user = insert(:user)
      {:ok, _user_relationship} = User.block(user, other_user)

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "does not return users who have reblogged the status privately", %{
      conn: conn,
      activity: activity
    } do
      other_user = insert(:user)

      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user, %{"visibility" => "private"})

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "does not fail on an unauthenticated request", %{activity: activity} do
      other_user = insert(:user)
      {:ok, _, _} = CommonAPI.repeat(activity.id, other_user)

      response =
        build_conn()
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(:ok)

      [%{"id" => id}] = response
      assert id == other_user.id
    end

    test "requires authentication for private posts", %{user: user} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "@#{other_user.nickname} wanna get some #cofe together?",
          "visibility" => "direct"
        })

      build_conn()
      |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
      |> json_response(404)

      response =
        build_conn()
        |> assign(:user, other_user)
        |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["read:accounts"]))
        |> get("/api/v1/statuses/#{activity.id}/reblogged_by")
        |> json_response(200)

      assert [] == response
    end
  end

  test "context" do
    user = insert(:user)

    {:ok, %{id: id1}} = CommonAPI.post(user, %{"status" => "1"})
    {:ok, %{id: id2}} = CommonAPI.post(user, %{"status" => "2", "in_reply_to_status_id" => id1})
    {:ok, %{id: id3}} = CommonAPI.post(user, %{"status" => "3", "in_reply_to_status_id" => id2})
    {:ok, %{id: id4}} = CommonAPI.post(user, %{"status" => "4", "in_reply_to_status_id" => id3})
    {:ok, %{id: id5}} = CommonAPI.post(user, %{"status" => "5", "in_reply_to_status_id" => id4})

    response =
      build_conn()
      |> get("/api/v1/statuses/#{id3}/context")
      |> json_response(:ok)

    assert %{
             "ancestors" => [%{"id" => ^id1}, %{"id" => ^id2}],
             "descendants" => [%{"id" => ^id4}, %{"id" => ^id5}]
           } = response
  end

  test "returns the favorites of a user" do
    %{user: user, conn: conn} = oauth_access(["read:favourites"])
    other_user = insert(:user)

    {:ok, _} = CommonAPI.post(other_user, %{"status" => "bla"})
    {:ok, activity} = CommonAPI.post(other_user, %{"status" => "traps are happy"})

    {:ok, _, _} = CommonAPI.favorite(activity.id, user)

    first_conn = get(conn, "/api/v1/favourites")

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

    second_conn = get(conn, "/api/v1/favourites?since_id=#{last_like}")

    assert [second_status] = json_response(second_conn, 200)
    assert second_status["id"] == to_string(second_activity.id)

    third_conn = get(conn, "/api/v1/favourites?limit=0")

    assert [] = json_response(third_conn, 200)
  end
end
