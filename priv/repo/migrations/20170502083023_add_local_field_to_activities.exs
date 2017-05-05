defmodule Pleroma.Repo.Migrations.AddLocalFieldToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add :local, :boolean, default: true
    end

    create index(:activities, [:local])
  end
end
