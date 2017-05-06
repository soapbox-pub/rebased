defmodule Pleroma.Repo.Migrations.AddUniqueIndexToAPID do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:ap_id])
  end
end
