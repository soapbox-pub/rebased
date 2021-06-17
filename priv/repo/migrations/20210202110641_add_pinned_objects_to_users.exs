defmodule Pleroma.Repo.Migrations.AddPinnedObjectsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:pinned_objects, :map)
    end
  end
end
