defmodule Pleroma.Repo.Migrations.AddIndexToObjects do
  use Ecto.Migration

  def change do
    create index(:objects, [:data], using: :gin)
  end
end
