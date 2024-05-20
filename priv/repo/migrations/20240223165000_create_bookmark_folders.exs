# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateBookmarkFolders do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:bookmark_folders, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:emoji, :string)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    alter table(:bookmarks) do
      add_if_not_exists(
        :folder_id,
        references(:bookmark_folders, type: :uuid, on_delete: :nilify_all)
      )
    end

    create_if_not_exists(unique_index(:bookmark_folders, [:user_id, :name]))
  end
end
