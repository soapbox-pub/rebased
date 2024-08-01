# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BookmarkFolderTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.BookmarkFolder

  describe "create/3" do
    test "with valid params" do
      user = insert(:user)
      {:ok, folder} = BookmarkFolder.create(user.id, "Read later", "🕓")
      assert folder.user_id == user.id
      assert folder.name == "Read later"
      assert folder.emoji == "🕓"
    end

    test "with invalid params" do
      {:error, changeset} = BookmarkFolder.create(nil, "", "not an emoji")
      refute changeset.valid?

      assert changeset.errors == [
               emoji: {"Invalid emoji", []},
               user_id: {"can't be blank", [validation: :required]},
               name: {"can't be blank", [validation: :required]}
             ]
    end
  end

  test "update/3" do
    user = insert(:user)
    {:ok, folder} = BookmarkFolder.create(user.id, "Read ltaer")
    {:ok, folder} = BookmarkFolder.update(folder.id, "Read later")
    assert folder.name == "Read later"
  end

  test "for_user/1" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _} = BookmarkFolder.create(user.id, "Folder 1")
    {:ok, _} = BookmarkFolder.create(user.id, "Folder 2")
    {:ok, _} = BookmarkFolder.create(other_user.id, "Folder 3")

    folders = BookmarkFolder.for_user(user.id)

    assert length(folders) == 2
  end

  test "belongs_to_user?/2" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, folder} = BookmarkFolder.create(user.id, "Folder")

    assert true == BookmarkFolder.belongs_to_user?(folder.id, user.id)
    assert false == BookmarkFolder.belongs_to_user?(folder.id, other_user.id)
  end
end
