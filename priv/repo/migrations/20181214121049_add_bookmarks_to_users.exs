defmodule Pleroma.Repo.Migrations.AddBookmarksToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:bookmarks, {:array, :string}, null: false, default: [])
    end
  end
end
