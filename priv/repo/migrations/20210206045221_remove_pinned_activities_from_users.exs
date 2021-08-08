defmodule Pleroma.Repo.Migrations.RemovePinnedActivitiesFromUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove(:pinned_activities)
    end
  end

  def down do
    alter table(:users) do
      add(:pinned_activities, {:array, :string}, default: [])
    end
  end
end
