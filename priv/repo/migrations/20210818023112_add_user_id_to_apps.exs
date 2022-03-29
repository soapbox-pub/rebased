# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUserIdToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
    end

    create_if_not_exists(index(:apps, [:user_id]))
  end
end
