defmodule Pleroma.Repo.Migrations.AddUserAndHub do
  use Ecto.Migration

  def change do
    alter table(:websub_client_subscriptions) do
      add(:hub, :string)
      add(:user_id, references(:users))
    end
  end
end
