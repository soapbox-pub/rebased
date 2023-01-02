# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateDeliveries do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:deliveries) do
      add(:object_id, references(:objects, type: :id), null: false)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
    end

    create_if_not_exists(index(:deliveries, :object_id, name: :deliveries_object_id))
    create_if_not_exists(unique_index(:deliveries, [:user_id, :object_id]))
  end
end
