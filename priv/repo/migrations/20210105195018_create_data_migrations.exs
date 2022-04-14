# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateDataMigrations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:data_migrations) do
      add(:name, :string, null: false)
      add(:state, :integer, default: 1)
      add(:feature_lock, :boolean, default: false)
      add(:params, :map, default: %{})
      add(:data, :map, default: %{})

      timestamps()
    end

    create_if_not_exists(unique_index(:data_migrations, [:name]))
  end
end
