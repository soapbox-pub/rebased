# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FilterTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  alias Oban.Job
  alias Pleroma.Filter

  setup do
    [user: insert(:user)]
  end

  describe "creating filters" do
    test "creation validation error", %{user: user} do
      attrs = %{
        user_id: user.id,
        expires_in: 60
      }

      {:error, _} = Filter.create(attrs)

      assert Repo.all(Job) == []
    end

    test "use passed expires_at instead expires_in", %{user: user} do
      now = NaiveDateTime.utc_now()

      attrs = %{
        user_id: user.id,
        expires_at: now,
        phrase: "knights",
        context: ["home"],
        expires_in: 600
      }

      {:ok, %Filter{} = filter} = Filter.create(attrs)

      result = Filter.get(filter.filter_id, user)
      assert result.expires_at == NaiveDateTime.truncate(now, :second)

      [job] = Repo.all(Job)

      assert DateTime.truncate(job.scheduled_at, :second) ==
               now |> NaiveDateTime.truncate(:second) |> DateTime.from_naive!("Etc/UTC")
    end

    test "creating one filter", %{user: user} do
      attrs = %{
        user_id: user.id,
        filter_id: 42,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter} = Filter.create(attrs)
      result = Filter.get(filter.filter_id, user)
      assert attrs.phrase == result.phrase
    end

    test "creating with expired_at", %{user: user} do
      attrs = %{
        user_id: user.id,
        filter_id: 42,
        phrase: "knights",
        context: ["home"],
        expires_in: 60
      }

      {:ok, %Filter{} = filter} = Filter.create(attrs)
      result = Filter.get(filter.filter_id, user)
      assert attrs.phrase == result.phrase

      assert [_] = Repo.all(Job)
    end

    test "creating one filter without a pre-defined filter_id", %{user: user} do
      attrs = %{
        user_id: user.id,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter} = Filter.create(attrs)
      # Should start at 1
      assert filter.filter_id == 1
    end

    test "creating additional filters uses previous highest filter_id + 1", %{user: user} do
      filter1 = insert(:filter, user: user)

      attrs = %{
        user_id: user.id,
        # No filter_id
        phrase: "who",
        context: ["home"]
      }

      {:ok, %Filter{} = filter2} = Filter.create(attrs)
      assert filter2.filter_id == filter1.filter_id + 1
    end

    test "filter_id is unique per user", %{user: user_one} do
      user_two = insert(:user)

      attrs1 = %{
        user_id: user_one.id,
        phrase: "knights",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_one} = Filter.create(attrs1)

      attrs2 = %{
        user_id: user_two.id,
        phrase: "who",
        context: ["home"]
      }

      {:ok, %Filter{} = filter_two} = Filter.create(attrs2)

      assert filter_one.filter_id == 1
      assert filter_two.filter_id == 1

      result_one = Filter.get(filter_one.filter_id, user_one)
      assert result_one.phrase == filter_one.phrase

      result_two = Filter.get(filter_two.filter_id, user_two)
      assert result_two.phrase == filter_two.phrase
    end
  end

  test "deleting a filter", %{user: user} do
    filter = insert(:filter, user: user)

    assert Repo.get(Filter, filter.id)
    {:ok, filter} = Filter.delete(filter)
    refute Repo.get(Filter, filter.id)
  end

  test "deleting a filter with expires_at is removing Oban job too", %{user: user} do
    attrs = %{
      user_id: user.id,
      phrase: "cofe",
      context: ["home"],
      expires_in: 600
    }

    {:ok, filter} = Filter.create(attrs)
    assert %Job{id: job_id} = Pleroma.Workers.PurgeExpiredFilter.get_expiration(filter.id)
    {:ok, _} = Filter.delete(filter)

    assert Repo.get(Job, job_id) == nil
  end

  test "getting all filters by an user", %{user: user} do
    filter1 = insert(:filter, user: user)
    filter2 = insert(:filter, user: user)

    filter_ids = user |> Filter.get_filters() |> collect_ids()

    assert filter1.id in filter_ids
    assert filter2.id in filter_ids
  end

  test "updating a filter", %{user: user} do
    filter = insert(:filter, user: user)

    changes = %{
      phrase: "who",
      context: ["home", "timeline"]
    }

    {:ok, updated_filter} = Filter.update(filter, changes)

    assert filter != updated_filter
    assert updated_filter.phrase == changes.phrase
    assert updated_filter.context == changes.context
  end

  test "updating with error", %{user: user} do
    filter = insert(:filter, user: user)

    changes = %{
      phrase: nil
    }

    {:error, _} = Filter.update(filter, changes)
  end
end
