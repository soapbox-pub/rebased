defmodule Pleroma.Repo.Migrations.CreateDomains do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:domains) do
      add(:domain, :citext)
      add(:public, :boolean)
      add(:resolves, :boolean)
      add(:last_checked_at, :naive_datetime)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists(unique_index(:domains, [:domain]))

    alter table(:users) do
      add(:domain_id, references(:domains))
    end

    create_if_not_exists(index(:users, [:domain_id]))
  end
end
