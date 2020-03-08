defmodule Pleroma.Repo.Migrations.DropObjectIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:objects, [:data], using: :gin))
  end
end
