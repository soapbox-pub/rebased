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
