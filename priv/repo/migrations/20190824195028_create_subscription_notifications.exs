defmodule Pleroma.Repo.Migrations.CreateSubscriptionNotifications do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:subscription_notifications) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    create_if_not_exists(index(:subscription_notifications, [:user_id]))
    create_if_not_exists(index(:subscription_notifications, ["id desc nulls last"]))
  end
end
