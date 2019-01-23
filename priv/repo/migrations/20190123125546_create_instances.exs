defmodule Pleroma.Repo.Migrations.CreateInstances do
  use Ecto.Migration

  def change do
    create table(:instances) do
      add :host, :string
      add :unreachable_since, :naive_datetime
      add :reachability_checked_at, :naive_datetime

      timestamps()
    end

    create unique_index(:instances, [:host])
    create index(:instances, [:unreachable_since])
  end
end
