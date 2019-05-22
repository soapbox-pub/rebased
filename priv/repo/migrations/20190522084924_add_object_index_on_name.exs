defmodule Pleroma.Repo.Migrations.AddObjectIndexOnName do
  use Ecto.Migration

  def change do
    create(index(:objects, ["(data->'name')"], name: :objects_name_index, using: :gin))
  end
end
