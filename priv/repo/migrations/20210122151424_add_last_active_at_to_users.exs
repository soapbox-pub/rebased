# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddLastActiveAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_active_at, :naive_datetime)
    end

    create_if_not_exists(index(:users, [:last_active_at]))
  end
end
