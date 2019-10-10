defmodule Pleroma.Repo.Migrations.AddIndexToObjects do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:objects, [:data], using: :gin))
  end
end
