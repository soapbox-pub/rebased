# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterControllerTest do
  use Pleroma.Web.ConnCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Filter
  alias Pleroma.Repo
  alias Pleroma.Workers.PurgeExpiredFilter

  test "non authenticated creation request", %{conn: conn} do
    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/filters", %{"phrase" => "knights", context: ["home"]})
      |> json_response(403)

    assert response["error"] == "Invalid credentials."
  end

  describe "creating" do
    setup do: oauth_access(["write:filters"])

    test "a common filter", %{conn: conn, user: user} do
      params = %{
        phrase: "knights",
        context: ["home"],
        irreversible: true
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", params)
        |> json_response_and_validate_schema(200)

      assert response["phrase"] == params.phrase
      assert response["context"] == params.context
      assert response["irreversible"] == true
      assert response["id"] != nil
      assert response["id"] != ""
      assert response["expires_at"] == nil

      filter = Filter.get(response["id"], user)
      assert filter.hide == true
    end

    test "a filter with expires_in", %{conn: conn, user: user} do
      in_seconds = 600

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", %{
          "phrase" => "knights",
          context: ["home"],
          expires_in: in_seconds
        })
        |> json_response_and_validate_schema(200)

      assert response["irreversible"] == false

      expires_at =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(in_seconds)
        |> Pleroma.Web.CommonAPI.Utils.to_masto_date()

      assert response["expires_at"] == expires_at

      filter = Filter.get(response["id"], user)

      id = filter.id

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      assert {:ok, %{id: ^id}} =
               perform_job(PurgeExpiredFilter, %{
                 filter_id: filter.id
               })

      assert Repo.aggregate(Filter, :count, :id) == 0
    end
  end

  test "fetching a list of filters" do
    %{user: user, conn: conn} = oauth_access(["read:filters"])

    %{filter_id: id1} = insert(:filter, user: user)
    %{filter_id: id2} = insert(:filter, user: user)

    id1 = to_string(id1)
    id2 = to_string(id2)

    assert [%{"id" => ^id2}, %{"id" => ^id1}] =
             conn
             |> get("/api/v1/filters")
             |> json_response_and_validate_schema(200)
  end

  test "fetching a list of filters without token", %{conn: conn} do
    insert(:filter)

    response =
      conn
      |> get("/api/v1/filters")
      |> json_response(403)

    assert response["error"] == "Invalid credentials."
  end

  test "get a filter" do
    %{user: user, conn: conn} = oauth_access(["read:filters"])

    # check whole_word false
    filter = insert(:filter, user: user, whole_word: false)

    resp1 =
      conn |> get("/api/v1/filters/#{filter.filter_id}") |> json_response_and_validate_schema(200)

    assert resp1["whole_word"] == false

    # check whole_word true
    filter = insert(:filter, user: user, whole_word: true)

    resp2 =
      conn |> get("/api/v1/filters/#{filter.filter_id}") |> json_response_and_validate_schema(200)

    assert resp2["whole_word"] == true
  end

  test "get a filter not_found error" do
    filter = insert(:filter)
    %{conn: conn} = oauth_access(["read:filters"])

    response =
      conn |> get("/api/v1/filters/#{filter.filter_id}") |> json_response_and_validate_schema(404)

    assert response["error"] == "Record not found"
  end

  describe "updating a filter" do
    setup do: oauth_access(["write:filters"])

    test "common" do
      %{conn: conn, user: user} = oauth_access(["write:filters"])

      filter =
        insert(:filter,
          user: user,
          hide: true,
          whole_word: true
        )

      params = %{
        phrase: "nii",
        context: ["public"],
        irreversible: false
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/filters/#{filter.filter_id}", params)
        |> json_response_and_validate_schema(200)

      assert response["phrase"] == params.phrase
      assert response["context"] == params.context
      assert response["irreversible"] == false
      assert response["whole_word"] == true
    end

    test "with adding expires_at", %{conn: conn, user: user} do
      filter = insert(:filter, user: user)
      in_seconds = 600

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/filters/#{filter.filter_id}", %{
          phrase: "nii",
          context: ["public"],
          expires_in: in_seconds,
          irreversible: true
        })
        |> json_response_and_validate_schema(200)

      assert response["irreversible"] == true

      assert response["expires_at"] ==
               NaiveDateTime.utc_now()
               |> NaiveDateTime.add(in_seconds)
               |> Pleroma.Web.CommonAPI.Utils.to_masto_date()

      filter = Filter.get(response["id"], user)

      id = filter.id

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: id}
      )

      assert {:ok, %{id: ^id}} =
               perform_job(PurgeExpiredFilter, %{
                 filter_id: id
               })

      assert Repo.aggregate(Filter, :count, :id) == 0
    end

    test "with removing expires_at", %{conn: conn, user: user} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", %{
          phrase: "cofe",
          context: ["home"],
          expires_in: 600
        })
        |> json_response_and_validate_schema(200)

      filter = Filter.get(response["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/filters/#{filter.filter_id}", %{
          phrase: "nii",
          context: ["public"],
          expires_in: nil,
          whole_word: true
        })
        |> json_response_and_validate_schema(200)

      refute_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      assert response["irreversible"] == false
      assert response["whole_word"] == true
      assert response["expires_at"] == nil
    end

    test "expires_at is the same in create and update so job is in db", %{conn: conn, user: user} do
      resp1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", %{
          phrase: "cofe",
          context: ["home"],
          expires_in: 600
        })
        |> json_response_and_validate_schema(200)

      filter = Filter.get(resp1["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      job = PurgeExpiredFilter.get_expiration(filter.id)

      resp2 =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/filters/#{filter.filter_id}", %{
          phrase: "nii",
          context: ["public"]
        })
        |> json_response_and_validate_schema(200)

      updated_filter = Filter.get(resp2["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: updated_filter.id}
      )

      after_update = PurgeExpiredFilter.get_expiration(updated_filter.id)

      assert resp1["expires_at"] == resp2["expires_at"]

      assert job.scheduled_at == after_update.scheduled_at
    end

    test "updating expires_at updates oban job too", %{conn: conn, user: user} do
      resp1 =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", %{
          phrase: "cofe",
          context: ["home"],
          expires_in: 600
        })
        |> json_response_and_validate_schema(200)

      filter = Filter.get(resp1["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      job = PurgeExpiredFilter.get_expiration(filter.id)

      resp2 =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/filters/#{filter.filter_id}", %{
          phrase: "nii",
          context: ["public"],
          expires_in: 300
        })
        |> json_response_and_validate_schema(200)

      updated_filter = Filter.get(resp2["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: updated_filter.id}
      )

      after_update = PurgeExpiredFilter.get_expiration(updated_filter.id)

      refute resp1["expires_at"] == resp2["expires_at"]

      refute job.scheduled_at == after_update.scheduled_at
    end
  end

  test "update filter without token", %{conn: conn} do
    filter = insert(:filter)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put("/api/v1/filters/#{filter.filter_id}", %{
        phrase: "nii",
        context: ["public"]
      })
      |> json_response(403)

    assert response["error"] == "Invalid credentials."
  end

  describe "delete a filter" do
    setup do: oauth_access(["write:filters"])

    test "common", %{conn: conn, user: user} do
      filter = insert(:filter, user: user)

      assert conn
             |> delete("/api/v1/filters/#{filter.filter_id}")
             |> json_response_and_validate_schema(200) == %{}

      assert Repo.all(Filter) == []
    end

    test "with expires_at", %{conn: conn, user: user} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/filters", %{
          phrase: "cofe",
          context: ["home"],
          expires_in: 600
        })
        |> json_response_and_validate_schema(200)

      filter = Filter.get(response["id"], user)

      assert_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      assert conn
             |> delete("/api/v1/filters/#{filter.filter_id}")
             |> json_response_and_validate_schema(200) == %{}

      refute_enqueued(
        worker: PurgeExpiredFilter,
        args: %{filter_id: filter.id}
      )

      assert Repo.all(Filter) == []
      assert Repo.all(Oban.Job) == []
    end
  end

  test "delete a filter without token", %{conn: conn} do
    filter = insert(:filter)

    response =
      conn
      |> delete("/api/v1/filters/#{filter.filter_id}")
      |> json_response(403)

    assert response["error"] == "Invalid credentials."
  end
end
