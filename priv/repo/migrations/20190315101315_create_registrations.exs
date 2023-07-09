# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:registrations, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:provider, :string)
      add(:uid, :string)
      add(:info, :map, default: %{})

      timestamps()
    end

    create_if_not_exists(unique_index(:registrations, [:provider, :uid]))
    create_if_not_exists(unique_index(:registrations, [:user_id, :provider, :uid]))
  end
end
