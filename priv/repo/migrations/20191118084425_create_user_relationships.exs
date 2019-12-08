defmodule Pleroma.Repo.Migrations.CreateUserRelationships do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_relationships) do
      add(:source_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:target_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:relationship_type, :integer, null: false)

      timestamps(updated_at: false)
    end

    create_if_not_exists(
      unique_index(:user_relationships, [:source_id, :relationship_type, :target_id])
    )
  end
end
