defmodule Pleroma.Repo.Migrations.CreateUserBlocks do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_blocks) do
      add(:blocker_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:blockee_id, references(:users, type: :uuid, on_delete: :delete_all))

      timestamps(updated_at: false)
    end

    create_if_not_exists(unique_index(:user_blocks, [:blocker_id, :blockee_id]))
  end
end
