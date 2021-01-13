# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.QueryTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.User.Query
  alias Pleroma.Web.ActivityPub.InternalFetchActor

  import Pleroma.Factory

  describe "internal users" do
    test "it filters out internal users by default" do
      %User{nickname: "internal.fetch"} = InternalFetchActor.get_actor()

      assert [_user] = User |> Repo.all()
      assert [] == %{} |> Query.build() |> Repo.all()
    end

    test "it filters out users without nickname by default" do
      insert(:user, %{nickname: nil})

      assert [_user] = User |> Repo.all()
      assert [] == %{} |> Query.build() |> Repo.all()
    end

    test "it returns internal users when enabled" do
      %User{nickname: "internal.fetch"} = InternalFetchActor.get_actor()
      insert(:user, %{nickname: nil})

      assert %{internal: true} |> Query.build() |> Repo.aggregate(:count) == 2
    end
  end
end
