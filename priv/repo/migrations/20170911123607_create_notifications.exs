defmodule Pleroma.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :activity_id, references(:activities, on_delete: :delete_all)
      add :seen, :boolean, default: false

      timestamps()
    end

    create index(:notifications, [:user_id])
  end
end
