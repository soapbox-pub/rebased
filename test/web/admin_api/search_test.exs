# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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
      insert(:user, deactivated: true)
      insert(:user, deactivated: true)
      insert(:user, deactivated: false)

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
      user = insert(:user, nickname: "bob", local: true, deactivated: false)

      {:ok, _results, total_count} = Search.user(%{query: ""})

      {:ok, [^user], count} =
        Search.user(%{
          query: "Bo",
          active: true,
          local: true
        })

      assert total_count == 3
      assert count == 1
    end

    test "it returns user by domain" do
      insert(:user)
      insert(:user)
      user = insert(:user, nickname: "some@domain.com")

      {:ok, _results, total} = Search.user()
      {:ok, [^user], count} = Search.user(%{query: "domain.com"})
      assert total == 3
      assert count == 1
    end

    test "it return user by full nickname" do
      insert(:user)
      insert(:user)
      user = insert(:user, nickname: "some@domain.com")

      {:ok, _results, total} = Search.user()
      {:ok, [^user], count} = Search.user(%{query: "some@domain.com"})
      assert total == 3
      assert count == 1
    end

    test "it returns admin user" do
      admin = insert(:user, is_admin: true)
      insert(:user)
      insert(:user)

      {:ok, _results, total} = Search.user()
      {:ok, [^admin], count} = Search.user(%{is_admin: true})
      assert total == 3
      assert count == 1
    end

    test "it returns moderator user" do
      moderator = insert(:user, is_moderator: true)
      insert(:user)
      insert(:user)

      {:ok, _results, total} = Search.user()
      {:ok, [^moderator], count} = Search.user(%{is_moderator: true})
      assert total == 3
      assert count == 1
    end

    test "it returns users with tags" do
      user1 = insert(:user, tags: ["first"])
      user2 = insert(:user, tags: ["second"])
      insert(:user)
      insert(:user)

      {:ok, _results, total} = Search.user()
      {:ok, users, count} = Search.user(%{tags: ["first", "second"]})
      assert total == 4
      assert count == 2
      assert user1 in users
      assert user2 in users
    end

    test "it returns user by display name" do
      user = insert(:user, name: "Display name")
      insert(:user)
      insert(:user)

      {:ok, _results, total} = Search.user()
      {:ok, [^user], count} = Search.user(%{name: "display"})

      assert total == 3
      assert count == 1
    end

    test "it returns user by email" do
      user = insert(:user, email: "some@example.com")
      insert(:user)
      insert(:user)

      {:ok, _results, total} = Search.user()
      {:ok, [^user], count} = Search.user(%{email: "some@example.com"})

      assert total == 3
      assert count == 1
    end
  end
end
