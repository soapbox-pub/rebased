defmodule Pleroma.Repo.Migrations.AddLocalIndexToUser do
  use Ecto.Migration

  def change do
    create index(:users, [:local])
  end
end
