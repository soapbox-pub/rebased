# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FilterTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Filter
  alias Pleroma.Repo

  describe "creating filters" do
    test "creating one filter" do
      user = insert(:user)

      query = %Filter{
        user_id: user.id,
        filter_id: 42,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter} = Filter.create(query)
      result = Filter.get(filter.filter_id, user)
      assert query.phrase == result.phrase
    end

    test "creating one filter without a pre-defined filter_id" do
      user = insert(:user)

      query = %Filter{
        user_id: user.id,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter} = Filter.create(query)
      # Should start at 1
      assert filter.filter_id == 1
    end

    test "creating additional filters uses previous highest filter_id + 1" do
      user = insert(:user)

      query_one = %Filter{
        user_id: user.id,
        filter_id: 42,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_one} = Filter.create(query_one)

      query_two = %Filter{
        user_id: user.id,
        # No filter_id
        phrase: "who",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_two} = Filter.create(query_two)
      assert filter_two.filter_id == filter_one.filter_id + 1
    end

    test "filter_id is unique per user" do
      user_one = insert(:user)
      user_two = insert(:user)

      query_one = %Filter{
        user_id: user_one.id,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_one} = Filter.create(query_one)

      query_two = %Filter{
        user_id: user_two.id,
        phrase: "who",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_two} = Filter.create(query_two)

      assert filter_one.filter_id == 1
      assert filter_two.filter_id == 1

      result_one = Filter.get(filter_one.filter_id, user_one)
      assert result_one.phrase == filter_one.phrase

      result_two = Filter.get(filter_two.filter_id, user_two)
      assert result_two.phrase == filter_two.phrase
    end
  end

  test "deleting a filter" do
    user = insert(:user)

    query = %Filter{
      user_id: user.id,
      filter_id: 0,
      phrase: "knights",
      context: ["home"]
    }

    {:ok, _filter} = Filter.create(query)
    {:ok, filter} = Filter.delete(query)
    assert is_nil(Repo.get(Filter, filter.filter_id))
  end

  test "getting all filters by an user" do
    user = insert(:user)

    query_one = %Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "knights",
      context: ["home"]
    }

    query_two = %Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "who",
      context: ["home"]
    }

    {:ok, filter_one} = Filter.create(query_one)
    {:ok, filter_two} = Filter.create(query_two)
    filters = Filter.get_filters(user)
    assert filter_one in filters
    assert filter_two in filters
  end

  test "updating a filter" do
    user = insert(:user)

    query_one = %Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "knights",
      context: ["home"]
    }

    changes = %{
      phrase: "who",
      context: ["home", "timeline"]
    }

    {:ok, filter_one} = Filter.create(query_one)
    {:ok, filter_two} = Filter.update(filter_one, changes)

    assert filter_one != filter_two
    assert filter_two.phrase == changes.phrase
    assert filter_two.context == changes.context
  end
end
