defmodule Pleroma.Repo.Migrations.RemoveActivitiesIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:activities, [:data]))
  end
end
