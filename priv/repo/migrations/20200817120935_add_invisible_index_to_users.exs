defmodule Pleroma.Repo.Migrations.AddInvisibleIndexToUsers do
  use Ecto.Migration

  def change do
    create(index(:users, [:invisible]))
  end
end
