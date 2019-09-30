defmodule Pleroma.Repo.Migrations.AddExpirationsTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:activity_expirations) do
      add(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all))
      add(:scheduled_at, :naive_datetime, null: false)
    end
  end
end
