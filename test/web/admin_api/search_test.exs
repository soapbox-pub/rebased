# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.SearchTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.AdminAPI.Search

  import Pleroma.Factory

  describe "search for admin" do
    test "it ignores case" do
      insert(:user, nickname: "papercoach")
      insert(:user, nickname: "CanadaPaperCoach")

      {:ok, _results, count} =
        Search.user(%{
          query: "paper",
          local: false,
          page: 1,
          page_size: 50
        })

      assert count == 2
    end

    test "it returns local/external users" do
      insert(:user, local: true)
      insert(:user, local: false)
      insert(:user, local: false)

      {:ok, _results, local_count} =
        Search.user(%{
          query: "",
          local: true
        })

      {:ok, _results, external_count} =
        Search.user(%{
          query: "",
          external: true
        })

      assert local_count == 1
      assert external_count == 2
    end

    test "it returns active/deactivated users" do
      insert(:user, info: %{deactivated: true})
      insert(:user, info: %{deactivated: true})
      insert(:user, info: %{deactivated: false})

      {:ok, _results, active_count} =
        Search.user(%{
          query: "",
          active: true
        })

      {:ok, _results, deactivated_count} =
        Search.user(%{
          query: "",
          deactivated: true
        })

      assert active_count == 1
      assert deactivated_count == 2
    end

    test "it returns specific user" do
      insert(:user)
      insert(:user)
      insert(:user, nickname: "bob", local: true, info: %{deactivated: false})

      {:ok, _results, total_count} = Search.user(%{query: ""})

      {:ok, _results, count} =
        Search.user(%{
          query: "Bo",
          active: true,
          local: true
        })

      assert total_count == 3
      assert count == 1
    end
  end
end
