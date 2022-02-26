# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateHashtags do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:hashtags) do
      add(:name, :citext, null: false)

      timestamps()
    end

    create_if_not_exists(unique_index(:hashtags, [:name]))
  end
end
