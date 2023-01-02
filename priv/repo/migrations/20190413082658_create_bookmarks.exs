# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:bookmarks) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    create_if_not_exists(unique_index(:bookmarks, [:user_id, :activity_id]))
  end
end
