defmodule Pleroma.Repo.Migrations.AddTypeToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add(:type, :string)
    end
  end
end
