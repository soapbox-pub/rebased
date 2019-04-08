defmodule Pleroma.Repo.Migrations.CreateScheduledActivities do
  use Ecto.Migration

  def change do
    create table(:scheduled_activities) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:scheduled_at, :naive_datetime, null: false)
      add(:params, :map, null: false)

      timestamps()
    end

    create(index(:scheduled_activities, [:scheduled_at]))
    create(index(:scheduled_activities, [:user_id]))
  end
end
