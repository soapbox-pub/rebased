defmodule Pleroma.Repo.Migrations.CreateUserMutes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_mutes) do
      add(:muter_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:mutee_id, references(:users, type: :uuid, on_delete: :delete_all))

      timestamps(updated_at: false)
    end

    create_if_not_exists(unique_index(:user_mutes, [:muter_id, :mutee_id]))
  end
end
