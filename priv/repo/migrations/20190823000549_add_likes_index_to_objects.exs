defmodule Pleroma.Repo.Migrations.AddLikesIndexToObjects do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:objects, ["(data->'likes')"], using: :gin, name: :objects_likes))
  end
end
