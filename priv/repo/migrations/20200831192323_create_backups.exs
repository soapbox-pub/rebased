defmodule Pleroma.Repo.Migrations.CreateBackups do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:backups) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:file_name, :string, null: false)
      add(:content_type, :string, null: false)
      add(:processed, :boolean, null: false, default: false)
      add(:file_size, :bigint)

      timestamps()
    end

    create_if_not_exists(index(:backups, [:user_id]))
  end
end
