defmodule Pleroma.Repo.Migrations.AddAcceptsJoinsToGroups do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_joins, :boolean, default: false)
    end
  end
end
