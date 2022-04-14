# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateInstances do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:instances) do
      add(:host, :string)
      add(:unreachable_since, :naive_datetime_usec)

      timestamps()
    end

    create_if_not_exists(unique_index(:instances, [:host]))
    create_if_not_exists(index(:instances, [:unreachable_since]))
  end
end
