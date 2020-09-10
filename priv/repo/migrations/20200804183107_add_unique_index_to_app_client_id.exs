defmodule Pleroma.Repo.Migrations.AddUniqueIndexToAppClientId do
  use Ecto.Migration

  def change do
    create(unique_index(:apps, [:client_id]))
  end
end
