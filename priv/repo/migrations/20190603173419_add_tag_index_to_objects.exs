defmodule Pleroma.Repo.Migrations.AddTagIndexToObjects do
  use Ecto.Migration

  def change do
    drop_if_exists index(:activities, ["(data #> '{\"object\",\"tag\"}')"], using: :gin, name: :activities_tags)
    create index(:objects, ["(data->'tag')"], using: :gin, name: :objects_tags)
  end
end
