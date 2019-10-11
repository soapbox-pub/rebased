defmodule Pleroma.Repo.Migrations.AddUniqueIndexToAPID do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:users, [:ap_id]))
  end
end
