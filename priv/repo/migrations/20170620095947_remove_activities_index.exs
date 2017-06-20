defmodule Pleroma.Repo.Migrations.RemoveActivitiesIndex do
  use Ecto.Migration

  def change do
    drop index(:activities, [:data])
  end
end
