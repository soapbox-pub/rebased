defmodule Pleroma.Repo.Migrations.ForcePinnedObjectsToExist do
  use Ecto.Migration

  def change do
    execute("UPDATE users SET pinned_objects = '{}' WHERE pinned_objects IS NULL")

    alter table("users") do
      modify(:pinned_objects, :map, null: false, default: %{})
    end
  end
end
