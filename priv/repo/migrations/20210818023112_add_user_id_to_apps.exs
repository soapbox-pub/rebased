defmodule Pleroma.Repo.Migrations.AddUserIdToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
    end
  end
end
