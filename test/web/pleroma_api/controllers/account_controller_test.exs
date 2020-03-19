# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AccountControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Swoosh.TestAssertions

  @image "data:image/gif;base64,R0lGODlhEAAQAMQAAORHHOVSKudfOulrSOp3WOyDZu6QdvCchPGolfO0o/XBs/fNwfjZ0frl3/zy7////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAkAABAALAAAAAAQABAAAAVVICSOZGlCQAosJ6mu7fiyZeKqNKToQGDsM8hBADgUXoGAiqhSvp5QAnQKGIgUhwFUYLCVDFCrKUE1lBavAViFIDlTImbKC5Gm2hB0SlBCBMQiB0UjIQA7"

  describe "POST /api/v1/pleroma/accounts/confirmation_resend" do
    setup do
      {:ok, user} =
        insert(:user)
        |> User.confirmation_changeset(need_confirmation: true)
        |> User.update_and_set_cache()

      assert user.confirmation_pending

      [user: user]
    end

    clear_config([:instance, :account_activation_required]) do
      Config.put([:instance, :account_activation_required], true)
    end

    test "resend account confirmation email", %{conn: conn, user: user} do
      conn
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

  describe "PATCH /api/v1/pleroma/accounts/update_avatar" do
    setup do: oauth_access(["write:accounts"])

    test "user avatar can be set", %{user: user, conn: conn} do
      avatar_image = File.read!("test/fixtures/avatar_data_uri")

      conn = patch(conn, "/api/v1/pleroma/accounts/update_avatar", %{img: avatar_image})

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

    test "user avatar can be reset", %{user: user, conn: conn} do
      conn = patch(conn, "/api/v1/pleroma/accounts/update_avatar", %{img: ""})

      user = User.get_cached_by_id(user.id)

      assert user.avatar == nil

      assert %{"url" => nil} = json_response(conn, 200)
    end
  end

  describe "PATCH /api/v1/pleroma/accounts/update_banner" do
    setup do: oauth_access(["write:accounts"])

    test "can set profile banner", %{user: user, conn: conn} do
      conn = patch(conn, "/api/v1/pleroma/accounts/update_banner", %{"banner" => @image})

      user = refresh_record(user)
      assert user.banner["type"] == "Image"

      assert %{"url" => _} = json_response(conn, 200)
    end

    test "can reset profile banner", %{user: user, conn: conn} do
      conn = patch(conn, "/api/v1/pleroma/accounts/update_banner", %{"banner" => ""})

      user = refresh_record(user)
      assert user.banner == %{}

      assert %{"url" => nil} = json_response(conn, 200)
    end
  end

  describe "PATCH /api/v1/pleroma/accounts/update_background" do
    setup do: oauth_access(["write:accounts"])

    test "background image can be set", %{user: user, conn: conn} do
      conn = patch(conn, "/api/v1/pleroma/accounts/update_background", %{"img" => @image})

      user = refresh_record(user)
      assert user.background["type"] == "Image"
      assert %{"url" => _} = json_response(conn, 200)
    end

    test "background image can be reset", %{user: user, conn: conn} do
      conn = patch(conn, "/api/v1/pleroma/accounts/update_background", %{"img" => ""})

      user = refresh_record(user)
      assert user.background == %{}
      assert %{"url" => nil} = json_response(conn, 200)
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
        |> json_response(:ok)

      [like] = response

      assert length(response) == 1
      assert like["id"] == activity.id
    end

    test "does not return favorites for specified user_id when user is not logged in", %{
      user: user
    } do
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      build_conn()
      |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
      |> json_response(403)
    end

    test "returns favorited DM only when user is logged in and he is one of recipients", %{
      current_user: current_user,
      user: user
    } do
      {:ok, direct} =
        CommonAPI.post(current_user, %{
          "status" => "Hi @#{user.nickname}!",
          "visibility" => "direct"
        })

      CommonAPI.favorite(user, direct.id)

      for u <- [user, current_user] do
        response =
          build_conn()
          |> assign(:user, u)
          |> assign(:token, insert(:oauth_token, user: u, scopes: ["read:favourites"]))
          |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
          |> json_response(:ok)

        assert length(response) == 1
      end

      build_conn()
      |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
      |> json_response(403)
    end

    test "does not return others' favorited DM when user is not one of recipients", %{
      conn: conn,
      user: user
    } do
      user_two = insert(:user)

      {:ok, direct} =
        CommonAPI.post(user_two, %{
          "status" => "Hi @#{user.nickname}!",
          "visibility" => "direct"
        })

      CommonAPI.favorite(user, direct.id)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

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
      user: user
    } do
      7
      |> insert_list(:note_activity)
      |> Enum.each(fn activity ->
        CommonAPI.favorite(user, activity.id)
      end)

      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites", %{limit: "3"})
        |> json_response(:ok)

      assert length(response) == 3
    end

    test "returns empty response when user does not have any favorited statuses", %{
      conn: conn,
      user: user
    } do
      response =
        conn
        |> get("/api/v1/pleroma/accounts/#{user.id}/favourites")
        |> json_response(:ok)

      assert Enum.empty?(response)
    end

    test "returns 404 error when specified user is not exist", %{conn: conn} do
      conn = get(conn, "/api/v1/pleroma/accounts/test/favourites")

      assert json_response(conn, 404) == %{"error" => "Record not found"}
    end

    test "returns 403 error when user has hidden own favorites", %{conn: conn} do
      user = insert(:user, hide_favorites: true)
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      conn = get(conn, "/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert json_response(conn, 403) == %{"error" => "Can't get favorites"}
    end

    test "hides favorites for new users by default", %{conn: conn} do
      user = insert(:user)
      activity = insert(:note_activity)
      CommonAPI.favorite(user, activity.id)

      assert user.hide_favorites
      conn = get(conn, "/api/v1/pleroma/accounts/#{user.id}/favourites")

      assert json_response(conn, 403) == %{"error" => "Can't get favorites"}
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

      assert %{"id" => _id, "subscribing" => true} = json_response(ret_conn, 200)

      conn = post(conn, "/api/v1/pleroma/accounts/#{subscription_target.id}/unsubscribe")

      assert %{"id" => _id, "subscribing" => false} = json_response(conn, 200)
    end
  end

  describe "subscribing" do
    test "returns 404 when subscription_target not found" do
      %{conn: conn} = oauth_access(["write:follows"])

      conn = post(conn, "/api/v1/pleroma/accounts/target_id/subscribe")

      assert %{"error" => "Record not found"} = json_response(conn, 404)
    end
  end

  describe "unsubscribing" do
    test "returns 404 when subscription_target not found" do
      %{conn: conn} = oauth_access(["follow"])

      conn = post(conn, "/api/v1/pleroma/accounts/target_id/unsubscribe")

      assert %{"error" => "Record not found"} = json_response(conn, 404)
    end
  end
end
