defmodule Pleroma.Repo.Migrations.AddHashtagsIndexToObjects do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:objects, ["(data->'tag')"], using: :gin, name: :objects_tags))

    create_if_not_exists(
      index(:objects, ["(data->'hashtags')"], using: :gin, name: :objects_hashtags)
    )
  end
end
