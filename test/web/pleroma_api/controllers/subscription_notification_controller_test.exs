# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SubscriptionNotificationControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Repo
  alias Pleroma.SubscriptionNotification
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance, :public])
  clear_config([:rich_media, :enabled])

  describe "subscription_notifications" do
    setup do
      user = insert(:user)
      subscriber = insert(:user)

      User.subscribe(subscriber, user)

      {:ok, %{user: user, subscriber: subscriber}}
    end

    test "list of notifications", %{conn: conn, user: user, subscriber: subscriber} do
      status_text = "Hello"
      {:ok, _activity} = CommonAPI.post(user, %{"status" => status_text})
      path = subscription_notification_path(conn, :index)

      conn =
        conn
        |> assign(:user, subscriber)
        |> get(path)

      assert [%{"status" => %{"content" => response}} | _rest] = json_response(conn, 200)
      assert response == status_text
    end

    test "getting a single notification", %{conn: conn, user: user, subscriber: subscriber} do
      status_text = "Hello"

      {:ok, _activity} = CommonAPI.post(user, %{"status" => status_text})
      [notification] = Repo.all(SubscriptionNotification)

      path = subscription_notification_path(conn, :show, notification)

      conn =
        conn
        |> assign(:user, subscriber)
        |> get(path)

      assert %{"status" => %{"content" => response}} = json_response(conn, 200)
      assert response == status_text
    end

    test "dismissing a single notification also deletes it", %{
      conn: conn,
      user: user,
      subscriber: subscriber
    } do
      status_text = "Hello"
      {:ok, _activity} = CommonAPI.post(user, %{"status" => status_text})

      [notification] = Repo.all(SubscriptionNotification)

      conn =
        conn
        |> assign(:user, subscriber)
        |> post(subscription_notification_path(conn, :dismiss), %{"id" => notification.id})

      assert %{} = json_response(conn, 200)

      assert Repo.all(SubscriptionNotification) == []
    end

    test "clearing all notifications also deletes them", %{
      conn: conn,
      user: user,
      subscriber: subscriber
    } do
      status_text1 = "Hello"
      status_text2 = "Hello again"
      {:ok, _activity1} = CommonAPI.post(user, %{"status" => status_text1})
      {:ok, _activity2} = CommonAPI.post(user, %{"status" => status_text2})

      conn =
        conn
        |> assign(:user, subscriber)
        |> post(subscription_notification_path(conn, :clear))

      assert %{} = json_response(conn, 200)

      conn =
        build_conn()
        |> assign(:user, subscriber)
        |> get(subscription_notification_path(conn, :index))

      assert json_response(conn, 200) == []

      assert Repo.all(SubscriptionNotification) == []
    end

    test "paginates notifications using min_id, since_id, max_id, and limit", %{
      conn: conn,
      user: user,
      subscriber: subscriber
    } do
      {:ok, activity1} = CommonAPI.post(user, %{"status" => "Hello 1"})
      {:ok, activity2} = CommonAPI.post(user, %{"status" => "Hello 2"})
      {:ok, activity3} = CommonAPI.post(user, %{"status" => "Hello 3"})
      {:ok, activity4} = CommonAPI.post(user, %{"status" => "Hello 4"})

      notification1_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity1.id).id |> to_string()

      notification2_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity2.id).id |> to_string()

      notification3_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity3.id).id |> to_string()

      notification4_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity4.id).id |> to_string()

      conn = assign(conn, :user, subscriber)

      # min_id
      conn_res =
        get(
          conn,
          subscription_notification_path(conn, :index, %{
            "limit" => 2,
            "min_id" => notification1_id
          })
        )

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result

      # since_id
      conn_res =
        get(
          conn,
          subscription_notification_path(conn, :index, %{
            "limit" => 2,
            "since_id" => notification1_id
          })
        )

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification4_id}, %{"id" => ^notification3_id}] = result

      # max_id
      conn_res =
        get(
          conn,
          subscription_notification_path(conn, :index, %{
            "limit" => 2,
            "max_id" => notification4_id
          })
        )

      result = json_response(conn_res, 200)
      assert [%{"id" => ^notification3_id}, %{"id" => ^notification2_id}] = result
    end

    test "destroy multiple", %{conn: conn, user: user1, subscriber: user2} do
      # mutual subscription
      User.subscribe(user1, user2)

      {:ok, activity1} = CommonAPI.post(user1, %{"status" => "Hello 1"})
      {:ok, activity2} = CommonAPI.post(user1, %{"status" => "World 1"})
      {:ok, activity3} = CommonAPI.post(user2, %{"status" => "Hello 2"})
      {:ok, activity4} = CommonAPI.post(user2, %{"status" => "World 2"})

      notification1_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity1.id).id |> to_string()

      notification2_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity2.id).id |> to_string()

      notification3_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity3.id).id |> to_string()

      notification4_id =
        Repo.get_by(SubscriptionNotification, activity_id: activity4.id).id |> to_string()

      conn = assign(conn, :user, user1)

      conn_res = get(conn, subscription_notification_path(conn, :index))

      result = json_response(conn_res, 200)

      Enum.each(result, fn %{"id" => id} ->
        assert id in [notification3_id, notification4_id]
      end)

      conn2 = assign(conn, :user, user2)

      conn_res = get(conn2, subscription_notification_path(conn, :index))

      result = json_response(conn_res, 200)

      Enum.each(result, fn %{"id" => id} ->
        assert id in [notification1_id, notification2_id]
      end)

      conn_destroy =
        delete(conn, subscription_notification_path(conn, :destroy_multiple), %{
          "ids" => [notification3_id, notification4_id]
        })

      assert json_response(conn_destroy, 200) == %{}

      conn_res = get(conn2, subscription_notification_path(conn, :index))

      result = json_response(conn_res, 200)

      Enum.each(result, fn %{"id" => id} ->
        assert id in [notification1_id, notification2_id]
      end)

      assert length(Repo.all(SubscriptionNotification)) == 2
    end
  end
end
