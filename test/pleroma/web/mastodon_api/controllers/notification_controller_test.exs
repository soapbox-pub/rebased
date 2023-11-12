# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationControllerTest do
  use Pleroma.Web.ConnCase, async: false

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "does NOT render account/pleroma/relationship by default" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, [_notification]} = Notification.create_notifications(activity)

    response =
      conn
      |> assign(:user, user)
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(200)

    assert Enum.all?(response, fn n ->
             get_in(n, ["account", "pleroma", "relationship"]) == %{}
           end)
  end

  test "list of notifications" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    {:ok, [_notification]} = Notification.create_notifications(activity)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/notifications")

    expected_response =
      "hi <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{user.id}\" href=\"#{user.ap_id}\" rel=\"ugc\">@<span>#{user.nickname}</span></a></span>"

    assert [%{"status" => %{"content" => response}} | _rest] =
             json_response_and_validate_schema(conn, 200)

    assert response == expected_response
  end

  test "by default, does not contain pleroma:chat_mention" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, _activity} = CommonAPI.post_chat_message(other_user, user, "hey")

    result =
      conn
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(200)

    assert [] == result

    result =
      conn
      |> get("/api/v1/notifications?include_types[]=pleroma:chat_mention")
      |> json_response_and_validate_schema(200)

    assert [_] = result
  end

  test "by default, does not contain pleroma:report" do
    clear_config([:instance, :moderator_privileges], [:reports_manage_reports])

    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, user} = user |> User.admin_api_update(%{is_moderator: true})

    %{conn: conn} = oauth_access(["read:notifications"], user: user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hey"})

    {:ok, _report} =
      CommonAPI.report(third_user, %{account_id: other_user.id, status_ids: [activity.id]})

    result =
      conn
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(200)

    assert [] == result

    result =
      conn
      |> get("/api/v1/notifications?include_types[]=pleroma:report")
      |> json_response_and_validate_schema(200)

    assert [_] = result
  end

  test "Pleroma:report is hidden for non-privileged users" do
    clear_config([:instance, :moderator_privileges], [:reports_manage_reports])

    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, user} = user |> User.admin_api_update(%{is_moderator: true})

    %{conn: conn} = oauth_access(["read:notifications"], user: user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hey"})

    {:ok, _report} =
      CommonAPI.report(third_user, %{account_id: other_user.id, status_ids: [activity.id]})

    result =
      conn
      |> get("/api/v1/notifications?include_types[]=pleroma:report")
      |> json_response_and_validate_schema(200)

    assert [_] = result

    clear_config([:instance, :moderator_privileges], [])

    result =
      conn
      |> get("/api/v1/notifications?include_types[]=pleroma:report")
      |> json_response_and_validate_schema(200)

    assert [] == result
  end

  test "excludes mentions from blockers when blockers_visible is false" do
    clear_config([:activitypub, :blockers_visible], false)

    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    blocker = insert(:user)

    {:ok, _} = CommonAPI.block(blocker, user)
    {:ok, activity} = CommonAPI.post(blocker, %{status: "hi @#{user.nickname}"})

    {:ok, [_notification]} = Notification.create_notifications(activity)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/notifications")

    assert [] == json_response_and_validate_schema(conn, 200)
  end

  test "getting a single notification" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    {:ok, [notification]} = Notification.create_notifications(activity)

    conn = get(conn, "/api/v1/notifications/#{notification.id}")

    expected_response =
      "hi <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{user.id}\" href=\"#{user.ap_id}\" rel=\"ugc\">@<span>#{user.nickname}</span></a></span>"

    assert %{"status" => %{"content" => response}} = json_response_and_validate_schema(conn, 200)
    assert response == expected_response
  end

  test "dismissing a single notification (deprecated endpoint)" do
    %{user: user, conn: conn} = oauth_access(["write:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    {:ok, [notification]} = Notification.create_notifications(activity)

    conn =
      conn
      |> assign(:user, user)
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/notifications/dismiss", %{"id" => to_string(notification.id)})

    assert %{} = json_response_and_validate_schema(conn, 200)
  end

  test "dismissing a single notification" do
    %{user: user, conn: conn} = oauth_access(["write:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    {:ok, [notification]} = Notification.create_notifications(activity)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/notifications/#{notification.id}/dismiss")

    assert %{} = json_response_and_validate_schema(conn, 200)
  end

  test "clearing all notifications" do
    %{user: user, conn: conn} = oauth_access(["write:notifications", "read:notifications"])
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    {:ok, [_notification]} = Notification.create_notifications(activity)

    ret_conn = post(conn, "/api/v1/notifications/clear")

    assert %{} = json_response_and_validate_schema(ret_conn, 200)

    ret_conn = get(conn, "/api/v1/notifications")

    assert all = json_response_and_validate_schema(ret_conn, 200)
    assert all == []
  end

  test "paginates notifications using min_id, since_id, max_id, and limit" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, activity1} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, activity2} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, activity3} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, activity4} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

    notification1_id = get_notification_id_by_activity(activity1)
    notification2_id = get_notification_id_by_activity(activity2)
    notification3_id = get_notification_id_by_activity(activity3)
    notification4_id = get_notification_id_by_activity(activity4)

    conn = assign(conn, :user, user)

    # min_id
    result =
      conn
      |> get("/api/v1/notifications?limit=2&min_id=#{notification1_id}")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result

    # since_id
    result =
      conn
      |> get("/api/v1/notifications?limit=2&since_id=#{notification1_id}")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result

    # max_id
    result =
      conn
      |> get("/api/v1/notifications?limit=2&max_id=#{notification4_id}")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result
  end

  describe "exclude_visibilities" do
    test "filters notifications for mentions" do
      %{user: user, conn: conn} = oauth_access(["read:notifications"])
      other_user = insert(:user)

      {:ok, public_activity} =
        CommonAPI.post(other_user, %{status: "@#{user.nickname}", visibility: "public"})

      {:ok, direct_activity} =
        CommonAPI.post(other_user, %{status: "@#{user.nickname}", visibility: "direct"})

      {:ok, unlisted_activity} =
        CommonAPI.post(other_user, %{status: "@#{user.nickname}", visibility: "unlisted"})

      {:ok, private_activity} =
        CommonAPI.post(other_user, %{status: "@#{user.nickname}", visibility: "private"})

      query = params_to_query(%{exclude_visibilities: ["public", "unlisted", "private"]})
      conn_res = get(conn, "/api/v1/notifications?" <> query)

      assert [%{"status" => %{"id" => id}}] = json_response_and_validate_schema(conn_res, 200)
      assert id == direct_activity.id

      query = params_to_query(%{exclude_visibilities: ["public", "unlisted", "direct"]})
      conn_res = get(conn, "/api/v1/notifications?" <> query)

      assert [%{"status" => %{"id" => id}}] = json_response_and_validate_schema(conn_res, 200)
      assert id == private_activity.id

      query = params_to_query(%{exclude_visibilities: ["public", "private", "direct"]})
      conn_res = get(conn, "/api/v1/notifications?" <> query)

      assert [%{"status" => %{"id" => id}}] = json_response_and_validate_schema(conn_res, 200)
      assert id == unlisted_activity.id

      query = params_to_query(%{exclude_visibilities: ["unlisted", "private", "direct"]})
      conn_res = get(conn, "/api/v1/notifications?" <> query)

      assert [%{"status" => %{"id" => id}}] = json_response_and_validate_schema(conn_res, 200)
      assert id == public_activity.id
    end

    test "filters notifications for Like activities" do
      user = insert(:user)
      %{user: other_user, conn: conn} = oauth_access(["read:notifications"])

      {:ok, public_activity} = CommonAPI.post(other_user, %{status: ".", visibility: "public"})

      {:ok, direct_activity} =
        CommonAPI.post(other_user, %{status: "@#{user.nickname}", visibility: "direct"})

      {:ok, unlisted_activity} =
        CommonAPI.post(other_user, %{status: ".", visibility: "unlisted"})

      {:ok, private_activity} = CommonAPI.post(other_user, %{status: ".", visibility: "private"})

      {:ok, _} = CommonAPI.favorite(user, public_activity.id)
      {:ok, _} = CommonAPI.favorite(user, direct_activity.id)
      {:ok, _} = CommonAPI.favorite(user, unlisted_activity.id)
      {:ok, _} = CommonAPI.favorite(user, private_activity.id)

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=direct")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      assert public_activity.id in activity_ids
      assert unlisted_activity.id in activity_ids
      assert private_activity.id in activity_ids
      refute direct_activity.id in activity_ids

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=unlisted")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      assert public_activity.id in activity_ids
      refute unlisted_activity.id in activity_ids
      assert private_activity.id in activity_ids
      assert direct_activity.id in activity_ids

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=private")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      assert public_activity.id in activity_ids
      assert unlisted_activity.id in activity_ids
      refute private_activity.id in activity_ids
      assert direct_activity.id in activity_ids

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=public")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      refute public_activity.id in activity_ids
      assert unlisted_activity.id in activity_ids
      assert private_activity.id in activity_ids
      assert direct_activity.id in activity_ids
    end

    test "filters notifications for Announce activities" do
      user = insert(:user)
      %{user: other_user, conn: conn} = oauth_access(["read:notifications"])

      {:ok, public_activity} = CommonAPI.post(other_user, %{status: ".", visibility: "public"})

      {:ok, unlisted_activity} =
        CommonAPI.post(other_user, %{status: ".", visibility: "unlisted"})

      {:ok, _} = CommonAPI.repeat(public_activity.id, user)
      {:ok, _} = CommonAPI.repeat(unlisted_activity.id, user)

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=unlisted")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      assert public_activity.id in activity_ids
      refute unlisted_activity.id in activity_ids
    end

    test "doesn't return less than the requested amount of records when the user's reply is liked" do
      user = insert(:user)
      %{user: other_user, conn: conn} = oauth_access(["read:notifications"])

      {:ok, mention} =
        CommonAPI.post(user, %{status: "@#{other_user.nickname}", visibility: "public"})

      {:ok, activity} = CommonAPI.post(user, %{status: ".", visibility: "public"})

      {:ok, reply} =
        CommonAPI.post(other_user, %{
          status: ".",
          visibility: "public",
          in_reply_to_status_id: activity.id
        })

      {:ok, _favorite} = CommonAPI.favorite(user, reply.id)

      activity_ids =
        conn
        |> get("/api/v1/notifications?exclude_visibilities[]=direct&limit=2")
        |> json_response_and_validate_schema(200)
        |> Enum.map(& &1["status"]["id"])

      assert [reply.id, mention.id] == activity_ids
    end
  end

  test "filters notifications using exclude_types" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, mention_activity} = CommonAPI.post(other_user, %{status: "hey @#{user.nickname}"})
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(other_user, create_activity.id)
    {:ok, reblog_activity} = CommonAPI.repeat(create_activity.id, other_user)
    {:ok, _, _, follow_activity} = CommonAPI.follow(other_user, user)

    mention_notification_id = get_notification_id_by_activity(mention_activity)
    favorite_notification_id = get_notification_id_by_activity(favorite_activity)
    reblog_notification_id = get_notification_id_by_activity(reblog_activity)
    follow_notification_id = get_notification_id_by_activity(follow_activity)

    query = params_to_query(%{exclude_types: ["mention", "favourite", "reblog"]})
    conn_res = get(conn, "/api/v1/notifications?" <> query)

    assert [%{"id" => ^follow_notification_id}] = json_response_and_validate_schema(conn_res, 200)

    query = params_to_query(%{exclude_types: ["favourite", "reblog", "follow"]})
    conn_res = get(conn, "/api/v1/notifications?" <> query)

    assert [%{"id" => ^mention_notification_id}] =
             json_response_and_validate_schema(conn_res, 200)

    query = params_to_query(%{exclude_types: ["reblog", "follow", "mention"]})
    conn_res = get(conn, "/api/v1/notifications?" <> query)

    assert [%{"id" => ^favorite_notification_id}] =
             json_response_and_validate_schema(conn_res, 200)

    query = params_to_query(%{exclude_types: ["follow", "mention", "favourite"]})
    conn_res = get(conn, "/api/v1/notifications?" <> query)

    assert [%{"id" => ^reblog_notification_id}] = json_response_and_validate_schema(conn_res, 200)
  end

  test "filters notifications using types" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, mention_activity} = CommonAPI.post(other_user, %{status: "hey @#{user.nickname}"})
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(other_user, create_activity.id)
    {:ok, reblog_activity} = CommonAPI.repeat(create_activity.id, other_user)
    {:ok, _, _, follow_activity} = CommonAPI.follow(other_user, user)

    mention_notification_id = get_notification_id_by_activity(mention_activity)
    favorite_notification_id = get_notification_id_by_activity(favorite_activity)
    reblog_notification_id = get_notification_id_by_activity(reblog_activity)
    follow_notification_id = get_notification_id_by_activity(follow_activity)

    conn_res = get(conn, "/api/v1/notifications?types[]=follow")

    assert [%{"id" => ^follow_notification_id}] = json_response_and_validate_schema(conn_res, 200)

    conn_res = get(conn, "/api/v1/notifications?types[]=mention")

    assert [%{"id" => ^mention_notification_id}] =
             json_response_and_validate_schema(conn_res, 200)

    conn_res = get(conn, "/api/v1/notifications?types[]=favourite")

    assert [%{"id" => ^favorite_notification_id}] =
             json_response_and_validate_schema(conn_res, 200)

    conn_res = get(conn, "/api/v1/notifications?types[]=reblog")

    assert [%{"id" => ^reblog_notification_id}] = json_response_and_validate_schema(conn_res, 200)

    result = conn |> get("/api/v1/notifications") |> json_response_and_validate_schema(200)

    assert length(result) == 4

    query = params_to_query(%{types: ["follow", "mention", "favourite", "reblog"]})

    result =
      conn
      |> get("/api/v1/notifications?" <> query)
      |> json_response_and_validate_schema(200)

    assert length(result) == 4
  end

  test "filtering falls back to include_types" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    other_user = insert(:user)

    {:ok, _activity} = CommonAPI.post(other_user, %{status: "hey @#{user.nickname}"})
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, _activity} = CommonAPI.favorite(other_user, create_activity.id)
    {:ok, _activity} = CommonAPI.repeat(create_activity.id, other_user)
    {:ok, _, _, follow_activity} = CommonAPI.follow(other_user, user)

    follow_notification_id = get_notification_id_by_activity(follow_activity)

    conn_res = get(conn, "/api/v1/notifications?include_types[]=follow")

    assert [%{"id" => ^follow_notification_id}] = json_response_and_validate_schema(conn_res, 200)
  end

  test "destroy multiple" do
    %{user: user, conn: conn} = oauth_access(["read:notifications", "write:notifications"])
    other_user = insert(:user)

    {:ok, activity1} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, activity2} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})
    {:ok, activity3} = CommonAPI.post(user, %{status: "hi @#{other_user.nickname}"})
    {:ok, activity4} = CommonAPI.post(user, %{status: "hi @#{other_user.nickname}"})

    notification1_id = get_notification_id_by_activity(activity1)
    notification2_id = get_notification_id_by_activity(activity2)
    notification3_id = get_notification_id_by_activity(activity3)
    notification4_id = get_notification_id_by_activity(activity4)

    result =
      conn
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification2_id}, %{"id" => ^notification1_id}] = result

    conn2 =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["read:notifications"]))

    result =
      conn2
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result

    query = params_to_query(%{ids: [notification1_id, notification2_id]})
    conn_destroy = delete(conn, "/api/v1/notifications/destroy_multiple?" <> query)

    assert json_response_and_validate_schema(conn_destroy, 200) == %{}

    result =
      conn2
      |> get("/api/v1/notifications")
      |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result
  end

  test "doesn't see notifications after muting user with notifications" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    user2 = insert(:user)

    {:ok, _, _, _} = CommonAPI.follow(user, user2)
    {:ok, _} = CommonAPI.post(user2, %{status: "hey @#{user.nickname}"})

    ret_conn = get(conn, "/api/v1/notifications")

    assert length(json_response_and_validate_schema(ret_conn, 200)) == 1

    {:ok, _user_relationships} = User.mute(user, user2)

    conn = get(conn, "/api/v1/notifications")

    assert json_response_and_validate_schema(conn, 200) == []
  end

  test "see notifications after muting user without notifications" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    user2 = insert(:user)

    {:ok, _, _, _} = CommonAPI.follow(user, user2)
    {:ok, _} = CommonAPI.post(user2, %{status: "hey @#{user.nickname}"})

    ret_conn = get(conn, "/api/v1/notifications")

    assert length(json_response_and_validate_schema(ret_conn, 200)) == 1

    {:ok, _user_relationships} = User.mute(user, user2, %{notifications: false})

    conn = get(conn, "/api/v1/notifications")

    assert length(json_response_and_validate_schema(conn, 200)) == 1
  end

  test "see notifications after muting user with notifications and with_muted parameter" do
    %{user: user, conn: conn} = oauth_access(["read:notifications"])
    user2 = insert(:user)

    {:ok, _, _, _} = CommonAPI.follow(user, user2)
    {:ok, _} = CommonAPI.post(user2, %{status: "hey @#{user.nickname}"})

    ret_conn = get(conn, "/api/v1/notifications")

    assert length(json_response_and_validate_schema(ret_conn, 200)) == 1

    {:ok, _user_relationships} = User.mute(user, user2)

    conn = get(conn, "/api/v1/notifications?with_muted=true")

    assert length(json_response_and_validate_schema(conn, 200)) == 1
  end

  test "see move notifications" do
    old_user = insert(:user)
    new_user = insert(:user, also_known_as: [old_user.ap_id])
    %{user: follower, conn: conn} = oauth_access(["read:notifications"])

    User.follow(follower, old_user)
    Pleroma.Web.ActivityPub.ActivityPub.move(old_user, new_user)
    Pleroma.Tests.ObanHelpers.perform_all()

    conn = get(conn, "/api/v1/notifications")

    assert length(json_response_and_validate_schema(conn, 200)) == 1
  end

  describe "link headers" do
    test "preserves parameters in link headers" do
      %{user: user, conn: conn} = oauth_access(["read:notifications"])
      other_user = insert(:user)

      {:ok, activity1} =
        CommonAPI.post(other_user, %{
          status: "hi @#{user.nickname}",
          visibility: "public"
        })

      {:ok, activity2} =
        CommonAPI.post(other_user, %{
          status: "hi @#{user.nickname}",
          visibility: "public"
        })

      notification1 = Repo.get_by(Notification, activity_id: activity1.id)
      notification2 = Repo.get_by(Notification, activity_id: activity2.id)

      conn =
        conn
        |> assign(:user, user)
        |> get("/api/v1/notifications?limit=5")

      assert [link_header] = get_resp_header(conn, "link")
      assert link_header =~ ~r/limit=5/
      assert link_header =~ ~r/min_id=#{notification2.id}/
      assert link_header =~ ~r/max_id=#{notification1.id}/
    end
  end

  describe "from specified user" do
    test "account_id" do
      %{user: user, conn: conn} = oauth_access(["read:notifications"])

      %{id: account_id} = other_user1 = insert(:user)
      other_user2 = insert(:user)

      {:ok, _activity} = CommonAPI.post(other_user1, %{status: "hi @#{user.nickname}"})
      {:ok, _activity} = CommonAPI.post(other_user2, %{status: "bye @#{user.nickname}"})

      assert [%{"account" => %{"id" => ^account_id}}] =
               conn
               |> assign(:user, user)
               |> get("/api/v1/notifications?account_id=#{account_id}")
               |> json_response_and_validate_schema(200)

      assert %{"error" => "Account is not found"} =
               conn
               |> assign(:user, user)
               |> get("/api/v1/notifications?account_id=cofe")
               |> json_response_and_validate_schema(404)
    end
  end

  defp get_notification_id_by_activity(%{id: id}) do
    Notification
    |> Repo.get_by(activity_id: id)
    |> Map.get(:id)
    |> to_string()
  end

  defp params_to_query(%{} = params) do
    Enum.map_join(params, "&", fn
      {k, v} when is_list(v) -> Enum.map_join(v, "&", &"#{k}[]=#{&1}")
      {k, v} -> k <> "=" <> v
    end)
  end
end
