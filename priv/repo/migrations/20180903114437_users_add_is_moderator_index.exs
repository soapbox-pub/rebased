# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UsersAddIsModeratorIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:users, ["(info->'is_moderator')"], name: :users_is_moderator_index, using: :gin)
    )
  end
end
