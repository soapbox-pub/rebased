# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.MeilisearchTest do
  require Pleroma.Constants

  use Pleroma.DataCase

  import Pleroma.Factory
  import Tesla.Mock
  import Mock

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Search.Meilisearch

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "meilisearch" do
    setup do: clear_config([Pleroma.Search, :module], Meilisearch)

    setup_with_mocks(
      [
        {Meilisearch, [:passthrough],
         [
           add_to_index: fn a -> passthrough([a]) end,
           remove_from_index: fn a -> passthrough([a]) end
         ]}
      ],
      context,
      do: {:ok, context}
    )

    test "indexes a local post on creation" do
      user = insert(:user)

      mock_global(fn
        %{method: :post, url: "http://127.0.0.1:7700/indexes/objects/documents", body: body} ->
          assert match?(
                   [%{"content" => "guys i just don&#39;t wanna leave the swamp"}],
                   Jason.decode!(body)
                 )

          json(%{updateId: 1})
      end)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      assert_called(Meilisearch.add_to_index(activity))
    end

    test "doesn't index posts that are not public" do
      user = insert(:user)

      Enum.each(["unlisted", "private", "direct"], fn visiblity ->
        {:ok, _} =
          CommonAPI.post(user, %{
            status: "guys i just don't wanna leave the swamp",
            visibility: visiblity
          })
      end)

      history = call_history(Meilisearch)
      assert Enum.count(history) == 3

      Enum.each(history, fn {_, _, return} ->
        assert is_nil(return)
      end)
    end

    test "deletes posts from index when deleted locally" do
      user = insert(:user)

      mock_global(fn
        %{method: :post, url: "http://127.0.0.1:7700/indexes/objects/documents", body: body} ->
          assert match?(
                   [%{"content" => "guys i just don&#39;t wanna leave the swamp"}],
                   Jason.decode!(body)
                 )

          json(%{updateId: 1})

        %{method: :delete, url: "http://127.0.0.1:7700/indexes/objects/documents/" <> id} ->
          assert String.length(id) > 1
          json(%{updateId: 2})
      end)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      assert_called(Meilisearch.add_to_index(activity))

      {:ok, _} = CommonAPI.delete(activity.id, user)

      assert_called(Meilisearch.remove_from_index(:_))
    end
  end
end
