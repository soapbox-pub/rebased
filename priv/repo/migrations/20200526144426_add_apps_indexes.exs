defmodule Pleroma.Repo.Migrations.AddAppsIndexes do
  use Ecto.Migration

  def change do
    create(index(:apps, [:client_id, :client_secret]))
  end
end
