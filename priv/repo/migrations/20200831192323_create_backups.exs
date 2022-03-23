# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateBackups do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:backups) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:file_name, :string, null: false)
      add(:content_type, :string, null: false)
      add(:processed, :boolean, null: false, default: false)
      add(:file_size, :bigint)

      timestamps()
    end

    create_if_not_exists(index(:backups, [:user_id]))
  end
end
