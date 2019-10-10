defmodule Pleroma.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:local, :boolean, default: true)
      add(:info, :map)
    end
  end
end
