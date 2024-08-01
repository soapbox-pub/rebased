# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.MeilisearchTest do
  require Pleroma.Constants

  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import Tesla.Mock
  import Mox

  alias Pleroma.Search.Meilisearch
  alias Pleroma.UnstubbedConfigMock, as: Config
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.SearchIndexingWorker

  describe "meilisearch" do
    test "indexes a local post on creation" do
      user = insert(:user)

      Tesla.Mock.mock(fn
        %{
          method: :put,
          url: "http://127.0.0.1:7700/indexes/objects/documents",
          body: body
        } ->
          assert match?(
                   [%{"content" => "guys i just don&#39;t wanna leave the swamp"}],
                   Jason.decode!(body)
                 )

          # To make sure that the worker is called
          send(self(), "posted_to_meilisearch")

          %{
            "enqueuedAt" => "2023-11-12T12:36:46.927517Z",
            "indexUid" => "objects",
            "status" => "enqueued",
            "taskUid" => 6,
            "type" => "documentAdditionOrUpdate"
          }
          |> json()
      end)

      Config
      |> expect(:get, 3, fn
        [Pleroma.Search, :module], nil ->
          Meilisearch

        [Pleroma.Search.Meilisearch, :url], nil ->
          "http://127.0.0.1:7700"

        [Pleroma.Search.Meilisearch, :private_key], nil ->
          "secret"
      end)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      args = %{"op" => "add_to_index", "activity" => activity.id}

      assert_enqueued(
        worker: SearchIndexingWorker,
        args: args
      )

      assert :ok = perform_job(SearchIndexingWorker, args)
      assert_received("posted_to_meilisearch")
    end

    test "doesn't index posts that are not public" do
      user = insert(:user)

      Enum.each(["private", "direct"], fn visibility ->
        {:ok, activity} =
          CommonAPI.post(user, %{
            status: "guys i just don't wanna leave the swamp",
            visibility: visibility
          })

        args = %{"op" => "add_to_index", "activity" => activity.id}

        Config
        |> expect(:get, fn
          [Pleroma.Search, :module], nil ->
            Meilisearch
        end)

        assert_enqueued(worker: SearchIndexingWorker, args: args)
        assert :ok = perform_job(SearchIndexingWorker, args)
      end)
    end

    test "deletes posts from index when deleted locally" do
      user = insert(:user)

      Tesla.Mock.mock(fn
        %{
          method: :put,
          url: "http://127.0.0.1:7700/indexes/objects/documents",
          body: body
        } ->
          assert match?(
                   [%{"content" => "guys i just don&#39;t wanna leave the swamp"}],
                   Jason.decode!(body)
                 )

          %{
            "enqueuedAt" => "2023-11-12T12:36:46.927517Z",
            "indexUid" => "objects",
            "status" => "enqueued",
            "taskUid" => 6,
            "type" => "documentAdditionOrUpdate"
          }
          |> json()

        %{method: :delete, url: "http://127.0.0.1:7700/indexes/objects/documents/" <> id} ->
          send(self(), "called_delete")
          assert String.length(id) > 1
          json(%{})
      end)

      Config
      |> expect(:get, 6, fn
        [Pleroma.Search, :module], nil ->
          Meilisearch

        [Pleroma.Search.Meilisearch, :url], nil ->
          "http://127.0.0.1:7700"

        [Pleroma.Search.Meilisearch, :private_key], nil ->
          "secret"
      end)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      args = %{"op" => "add_to_index", "activity" => activity.id}
      assert_enqueued(worker: SearchIndexingWorker, args: args)
      assert :ok = perform_job(SearchIndexingWorker, args)

      {:ok, _} = CommonAPI.delete(activity.id, user)

      delete_args = %{"op" => "remove_from_index", "object" => activity.object.id}
      assert_enqueued(worker: SearchIndexingWorker, args: delete_args)
      assert :ok = perform_job(SearchIndexingWorker, delete_args)

      assert_received("called_delete")
    end
  end
end
