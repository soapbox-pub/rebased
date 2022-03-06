# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateConfig do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:config) do
      add(:key, :string)
      add(:value, :binary)
      timestamps()
    end

    create_if_not_exists(unique_index(:config, :key))
  end
end
