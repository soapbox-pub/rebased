# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateLists do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:lists) do
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:title, :string)
      add(:following, {:array, :string})

      timestamps()
    end

    create_if_not_exists(index(:lists, [:user_id]))
  end
end
