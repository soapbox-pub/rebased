defmodule Pleroma.Repo.Migrations.AddIsDiscoverableIndexToUsers do
  use Ecto.Migration

  def change do
    create(index(:users, [:is_discoverable]))
  end
end
