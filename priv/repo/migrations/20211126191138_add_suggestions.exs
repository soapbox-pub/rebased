# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddSuggestions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_suggested, :boolean, default: false, null: false)
    end

    create_if_not_exists(index(:users, [:is_suggested]))
  end
end
