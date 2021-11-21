defmodule Pleroma.Repo.Migrations.CreateUserNotes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_notes) do
      add(:source_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:target_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:comment, :string)

      timestamps()
    end

    create_if_not_exists(unique_index(:user_notes, [:source_id, :target_id]))
  end
end
