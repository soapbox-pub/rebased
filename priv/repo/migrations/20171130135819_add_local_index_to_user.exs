defmodule Pleroma.Repo.Migrations.AddLocalIndexToUser do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:users, [:local]))
  end
end
