# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.QueryTest do
  use Pleroma.DataCase, async: false

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

  test "is_suggested param" do
    _user1 = insert(:user, is_suggested: false)
    user2 = insert(:user, is_suggested: true)

    assert [^user2] =
             %{is_suggested: true}
             |> User.Query.build()
             |> Repo.all()
  end

  describe "is_privileged param" do
    setup do
      %{
        user: insert(:user, local: true, is_admin: false, is_moderator: false),
        moderator_user: insert(:user, local: true, is_admin: false, is_moderator: true),
        admin_user: insert(:user, local: true, is_admin: true, is_moderator: false),
        admin_moderator_user: insert(:user, local: true, is_admin: true, is_moderator: true),
        remote_user: insert(:user, local: false, is_admin: true, is_moderator: true),
        non_active_user:
          insert(:user, local: true, is_admin: true, is_moderator: true, is_active: false)
      }
    end

    test "doesn't return any users when there are no privileged roles" do
      clear_config([:instance, :admin_privileges], [])
      clear_config([:instance, :moderator_privileges], [])

      assert [] = User.Query.build(%{is_privileged: :cofe}) |> Repo.all()
    end

    test "returns moderator users if they are privileged", %{
      moderator_user: moderator_user,
      admin_moderator_user: admin_moderator_user
    } do
      clear_config([:instance, :admin_privileges], [])
      clear_config([:instance, :moderator_privileges], [:cofe])

      assert [_, _] = User.Query.build(%{is_privileged: :cofe}) |> Repo.all()
      assert moderator_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
      assert admin_moderator_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
    end

    test "returns admin users if they are privileged", %{
      admin_user: admin_user,
      admin_moderator_user: admin_moderator_user
    } do
      clear_config([:instance, :admin_privileges], [:cofe])
      clear_config([:instance, :moderator_privileges], [])

      assert [_, _] = User.Query.build(%{is_privileged: :cofe}) |> Repo.all()
      assert admin_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
      assert admin_moderator_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
    end

    test "returns admin and moderator users if they are both privileged", %{
      moderator_user: moderator_user,
      admin_user: admin_user,
      admin_moderator_user: admin_moderator_user
    } do
      clear_config([:instance, :admin_privileges], [:cofe])
      clear_config([:instance, :moderator_privileges], [:cofe])

      assert [_, _, _] = User.Query.build(%{is_privileged: :cofe}) |> Repo.all()
      assert admin_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
      assert moderator_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
      assert admin_moderator_user in (User.Query.build(%{is_privileged: :cofe}) |> Repo.all())
    end
  end
end
