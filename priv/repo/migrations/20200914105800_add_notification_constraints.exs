defmodule Pleroma.Repo.Migrations.AddNotificationConstraints do
  use Ecto.Migration

  def up do
    drop(constraint(:notifications, "notifications_activity_id_fkey"))

    alter table(:notifications) do
      modify(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all),
        null: false
      )
    end
  end

  def down do
    drop(constraint(:notifications, "notifications_activity_id_fkey"))

    alter table(:notifications) do
      modify(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all),
        null: true
      )
    end
  end
end
