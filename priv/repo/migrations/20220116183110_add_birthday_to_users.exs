# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddBirthdayToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:birthday, :date)
      add_if_not_exists(:show_birthday, :boolean, default: false, null: false)
    end

    create_if_not_exists(index(:users, [:show_birthday]))
  end
end
