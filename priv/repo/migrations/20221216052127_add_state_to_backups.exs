# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddStateToBackups do
  use Ecto.Migration

  def up do
    alter table(:backups) do
      add(:state, :integer, default: 5)
      add(:processed_number, :integer, default: 0)
    end
  end

  def down do
    alter table(:backups) do
      remove(:state)
      remove(:processed_number)
    end
  end
end
