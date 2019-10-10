defmodule Pleroma.Repo.Migrations.AddLocalFieldToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add(:local, :boolean, default: true)
    end

    create_if_not_exists(index(:activities, [:local]))
  end
end
