# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddTagsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:tags, {:array, :string})
    end

    create_if_not_exists(index(:users, [:tags], using: :gin))
  end
end
