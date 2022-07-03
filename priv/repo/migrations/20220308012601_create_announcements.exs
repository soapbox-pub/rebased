defmodule Pleroma.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:announcements, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:data, :map)
      add(:starts_at, :naive_datetime)
      add(:ends_at, :naive_datetime)
      add(:rendered, :map)

      timestamps()
    end

    create_if_not_exists table(:announcement_read_relationships) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:announcement_id, references(:announcements, type: :uuid, on_delete: :delete_all))

      timestamps(updated_at: false)
    end

    create_if_not_exists(
      unique_index(:announcement_read_relationships, [:user_id, :announcement_id])
    )
  end
end
