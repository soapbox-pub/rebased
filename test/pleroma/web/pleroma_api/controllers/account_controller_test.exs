# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AccountControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Swoosh.TestAssertions

  describe "POST /api/v1/pleroma/accounts/confirmation_resend" do
    setup do
      {:ok, user} =
        insert(:user)
        |> User.confirmation_changeset(set_confirmation: false)
        |> User.update_and_set_cache()

      refute user.is_confirmed

      [user: user]
    end

    setup do: clear_config([:instance, :account_activation_required], true)

    test "resend account confirmation email", %{conn: conn, user: user} do
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/pleroma/accounts/confirmation_resend?email=#{user.email}")
      |> json_response_and_validate_schema(:no_content)

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

    test "resend account confirmation email (with nickname)", %{conn: conn, user: user} do
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/pleroma/accounts/confirmation_resend?nickname=#{user.nickname}")
      |> json_response_and_validate_schema(:no_content)

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

  describe "getting favorites timeline of specified user" do
    setup do
      [current_user, user] = insert_pair(:user, hide_favorites: false)
      %{user: current_user, conn: conn} = oauth_access(["read:favourites"], user: current_user)
      [current_user: current_user, user: user, conn: conn]
    end

    test "returns list of statuses favorited by specified user", %{
      conn: conn,
      user: user
    } do
      [activity | _] = insert_pair(:note_activity)
      CommonAPI.favorite(user, activity.id)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response_and_validate_schema(:ok)

      [like] = response

      assert length(response) == 1
      assert like["id"] == activity.id
    end

    test "returns favorites for specified user_id when requester is not logged in", %{
      user: user
    } do
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      response =
        build_conn()
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response_and_validate_schema(200)

      assert length(response) == 1
    end

    test "returns favorited DM only when user is logged in and he is one of recipients", %{
      current_user: current_user,
      user: user
    } do
      {:ok, direct} =
        CommonAPI.post(current_user, %{
          status: "Hi @#{user.nickname}!",
          visibility: "direct"
        })

      CommonAPI.favorite(user, direct.id)

      for u <- [user, current_user] do
        response =
          build_conn()
          |> assign(:user, u)
          |> assign(:token, insert(:oauth_token, user: u, scopes: ["read:favourites"]))
          |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
          |> json_response_and_validate_schema(:ok)

        assert length(response) == 1
      end

      response =
        build_conn()
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response_and_validate_schema(200)

      assert length(response) == 0
    end

    test "does not return others' favorited DM when user is not one of recipients", %{
      conn: conn,
      user: user
    } do
      user_two = insert(:user)

      {:ok, direct} =
        CommonAPI.post(user_two, %{
          status: "Hi @#{user.nickname}!",
          visibility: "direct"
        })

      CommonAPI.favorite(user, direct.id)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response_and_validate_schema(:ok)

      assert Enum.empty?(response)
    end

    test "paginates favorites using since_id and max_id", %{
      conn: conn,
      user: user
    } do
      activities = insert_list(10, :note_activity)

      Enum.each(activities, fn activity ->
        CommonAPI.favorite(user, activity.id)
      end)

      third_activity = Enum.at(activities, 2)
      seventh_activity = Enum.at(activities, 6)

      response =
        conn
        |> get(
          "/api/v1/pleroma/accounts/#{user.id}/favourites?since_id=#{third_activity.id}&max_id=#{seventh_activity.id}"
        )
        |> json_response_and_validate_schema(:ok)

      assert length(response) == 3
      refute third_activity in response
      refute seventh_activity in response
    end

    test "limits favorites using limit parameter", %{
      conn: conn,
      user: user
    } do
      7
      |> insert_list(:note_activity)
      |> Enum.each(fn activity ->
        CommonAPI.favorite(user, activity.id)
      end)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites?limit=3")
        |> json_response_and_validate_schema(:ok)

      assert length(response) == 3
    end

    test "returns empty response when user does not have any favorited statuses", %{
      conn: conn,
      user: user
    } do
      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response_and_validate_schema(:ok)

      assert Enum.empty?(response)
    end

    test "returns 404 error when specified user is not exist", %{conn: conn} do
      conn = get(conn, "/api/v1/pleroma/accounts/test/favourites")

      assert json_response_and_validate_schema(conn, 404) == %{"error" => "Record not found"}
    end

    test "returns 403 error when user has hidden own favorites", %{conn: conn} do
      user = insert(:user, hide_favorites: true)
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      conn = get(conn, "/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert json_response_and_validate_schema(conn, 403) == %{"error" => "Can't get favorites"}
    end

    test "hides favorites for new users by default", %{conn: conn} do
      user = insert(:user)
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      assert user.hide_favorites
      conn = get(conn, "/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert json_response_and_validate_schema(conn, 403) == %{"error" => "Can't get favorites"}
    end
  end

  describe "subscribing / unsubscribing" do
    test "subscribing / unsubscribing to a user" do
      %{user: user, conn: conn} = oauth_access(["follow"])
      subscription_target = insert(:user)

      ret_conn =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/accounts/#{subscription_target.id}/subscribe")

      assert %{"id" => _id, "subscribing" => true} =
               json_response_and_validate_schema(ret_conn, 200)

      conn = post(conn, "/api/v1/pleroma/accounts/#{subscription_target.id}/unsubscribe")

      assert %{"id" => _id, "subscribing" => false} = json_response_and_validate_schema(conn, 200)
    end
  end

  describe "subscribing" do
    test "returns 404 when subscription_target not found" do
      %{conn: conn} = oauth_access(["write:follows"])

      conn = post(conn, "/api/v1/pleroma/accounts/target_id/subscribe")

      assert %{"error" => "Record not found"} = json_response_and_validate_schema(conn, 404)
    end
  end

  describe "unsubscribing" do
    test "returns 404 when subscription_target not found" do
      %{conn: conn} = oauth_access(["follow"])

      conn = post(conn, "/api/v1/pleroma/accounts/target_id/unsubscribe")

      assert %{"error" => "Record not found"} = json_response_and_validate_schema(conn, 404)
    end
  end

  describe "account endorsements" do
    test "returns a list of pinned accounts", %{conn: conn} do
      %{id: id1} = user1 = insert(:user)
      %{id: id2} = user2 = insert(:user)
      %{id: id3} = user3 = insert(:user)

      CommonAPI.follow(user1, user2)
      CommonAPI.follow(user1, user3)

      User.endorse(user1, user2)
      User.endorse(user1, user3)

      [%{"id" => ^id2}, %{"id" => ^id3}] =
        conn
        |> get("/api/v1/pleroma/accounts/#{id1}/endorsements")
        |> json_response_and_validate_schema(200)
    end

    test "returns 404 error when specified user is not exist", %{conn: conn} do
      conn = get(conn, "/api/v1/pleroma/accounts/test/endorsements")

      assert json_response_and_validate_schema(conn, 404) == %{"error" => "Record not found"}
    end
  end
end
