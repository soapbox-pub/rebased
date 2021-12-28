defmodule Pleroma.Repo.Migrations.AddUserIdToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
    end

    create_if_not_exists(index(:apps, [:user_id]))
  end
end
