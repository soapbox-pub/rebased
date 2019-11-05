defmodule Pleroma.Repo.Migrations.CreateMarkers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:markers) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:timeline, :string, default: "", null: false)
      add(:last_read_id, :string, default: "", null: false)
      add(:lock_version, :integer, default: 0, null: false)
      timestamps()
    end

    create_if_not_exists(unique_index(:markers, [:user_id, :timeline]))
  end
end
