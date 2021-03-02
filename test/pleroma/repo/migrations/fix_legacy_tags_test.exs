# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.FixLegacyTagsTest do
  alias Pleroma.User
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  import Pleroma.Tests.Helpers

  setup_all do: require_migration("20200802170532_fix_legacy_tags")

  test "change/0 converts legacy user tags into correct values", %{migration: migration} do
    user = insert(:user, tags: ["force_nsfw", "force_unlisted", "verified"])
    user2 = insert(:user)

    assert :ok == migration.change()

    fixed_user = User.get_by_id(user.id)
    fixed_user2 = User.get_by_id(user2.id)

    assert fixed_user.tags == ["mrf_tag:media-force-nsfw", "mrf_tag:force-unlisted", "verified"]
    assert fixed_user2.tags == []

    # user2 should not have been updated
    assert fixed_user2.updated_at == fixed_user2.inserted_at
  end
end
