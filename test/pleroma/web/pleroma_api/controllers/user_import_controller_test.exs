# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.UserImportControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Tests.ObanHelpers

  import Pleroma.Factory
  import Mock

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "POST /api/pleroma/follow_import" do
    setup do: oauth_access(["follow"])

    test "it returns HTTP 200", %{conn: conn} do
      user2 = insert(:user)

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/follow_import", %{"list" => "#{user2.ap_id}"})
               |> json_response_and_validate_schema(200)
    end

    test "it imports follow lists from file", %{conn: conn} do
      user2 = insert(:user)

      with_mocks([
        {File, [],
         read!: fn "follow_list.txt" ->
           "Account address,Show boosts\n#{user2.ap_id},true"
         end}
      ]) do
        assert "job started" ==
                 conn
                 |> put_req_header("content-type", "application/json")
                 |> post("/api/pleroma/follow_import", %{
                   "list" => %Plug.Upload{path: "follow_list.txt"}
                 })
                 |> json_response_and_validate_schema(200)

        assert [{:ok, job_result}] = ObanHelpers.perform_all()
        assert job_result == [refresh_record(user2)]
        assert [%Pleroma.User{follower_count: 1}] = job_result
      end
    end

    test "it imports new-style mastodon follow lists", %{conn: conn} do
      user2 = insert(:user)

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/follow_import", %{
          "list" => "Account address,Show boosts\n#{user2.ap_id},true"
        })
        |> json_response_and_validate_schema(200)

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
          |> put_req_header("content-type", "application/json")
          |> post("/api/pleroma/follow_import", %{"list" => "#{another_user.ap_id}"})

        if token == token3 do
          assert %{"error" => "Insufficient permissions: follow | write:follows."} ==
                   json_response(conn, 403)
        else
          assert json_response_and_validate_schema(conn, 200)
        end
      end
    end

    test "it imports follows with different nickname variations", %{conn: conn} do
      users = [user2, user3, user4, user5, user6] = insert_list(5, :user)

      identifiers =
        [
          user2.ap_id,
          user3.nickname,
          "  ",
          "@" <> user4.nickname,
          user5.nickname <> "@localhost",
          "@" <> user6.nickname <> "@localhost"
        ]
        |> Enum.join("\n")

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/follow_import", %{"list" => identifiers})
               |> json_response_and_validate_schema(200)

      assert [{:ok, job_result}] = ObanHelpers.perform_all()
      assert job_result == Enum.map(users, &refresh_record/1)
    end
  end

  describe "POST /api/pleroma/blocks_import" do
    # Note: "follow" or "write:blocks" permission is required
    setup do: oauth_access(["write:blocks"])

    test "it returns HTTP 200", %{conn: conn} do
      user2 = insert(:user)

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/blocks_import", %{"list" => "#{user2.ap_id}"})
               |> json_response_and_validate_schema(200)
    end

    test "it imports blocks users from file", %{conn: conn} do
      users = [user2, user3] = insert_list(2, :user)

      with_mocks([
        {File, [], read!: fn "blocks_list.txt" -> "#{user2.ap_id} #{user3.ap_id}" end}
      ]) do
        assert "job started" ==
                 conn
                 |> put_req_header("content-type", "application/json")
                 |> post("/api/pleroma/blocks_import", %{
                   "list" => %Plug.Upload{path: "blocks_list.txt"}
                 })
                 |> json_response_and_validate_schema(200)

        assert [{:ok, job_result}] = ObanHelpers.perform_all()
        assert job_result == users
      end
    end

    test "it imports blocks with different nickname variations", %{conn: conn} do
      users = [user2, user3, user4, user5, user6] = insert_list(5, :user)

      identifiers =
        [
          user2.ap_id,
          user3.nickname,
          "@" <> user4.nickname,
          user5.nickname <> "@localhost",
          "@" <> user6.nickname <> "@localhost"
        ]
        |> Enum.join(" ")

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/blocks_import", %{"list" => identifiers})
               |> json_response_and_validate_schema(200)

      assert [{:ok, job_result}] = ObanHelpers.perform_all()
      assert job_result == users
    end
  end

  describe "POST /api/pleroma/mutes_import" do
    # Note: "follow" or "write:mutes" permission is required
    setup do: oauth_access(["write:mutes"])

    test "it returns HTTP 200", %{user: user, conn: conn} do
      user2 = insert(:user)

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/mutes_import", %{"list" => "#{user2.ap_id}"})
               |> json_response_and_validate_schema(200)

      assert [{:ok, job_result}] = ObanHelpers.perform_all()
      assert job_result == [user2]
      assert Pleroma.User.mutes?(user, user2)
    end

    test "it imports mutes users from file", %{user: user, conn: conn} do
      users = [user2, user3] = insert_list(2, :user)

      with_mocks([
        {File, [], read!: fn "mutes_list.txt" -> "#{user2.ap_id} #{user3.ap_id}" end}
      ]) do
        assert "job started" ==
                 conn
                 |> put_req_header("content-type", "application/json")
                 |> post("/api/pleroma/mutes_import", %{
                   "list" => %Plug.Upload{path: "mutes_list.txt"}
                 })
                 |> json_response_and_validate_schema(200)

        assert [{:ok, job_result}] = ObanHelpers.perform_all()
        assert job_result == users
        assert Enum.all?(users, &Pleroma.User.mutes?(user, &1))
      end
    end

    test "it imports mutes with different nickname variations", %{user: user, conn: conn} do
      users = [user2, user3, user4, user5, user6] = insert_list(5, :user)

      identifiers =
        [
          user2.ap_id,
          user3.nickname,
          "@" <> user4.nickname,
          user5.nickname <> "@localhost",
          "@" <> user6.nickname <> "@localhost"
        ]
        |> Enum.join(" ")

      assert "job started" ==
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/mutes_import", %{"list" => identifiers})
               |> json_response_and_validate_schema(200)

      assert [{:ok, job_result}] = ObanHelpers.perform_all()
      assert job_result == users
      assert Enum.all?(users, &Pleroma.User.mutes?(user, &1))
    end
  end
end
