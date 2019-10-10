defmodule Pleroma.Repo.Migrations.AddFTSIndexToObjects do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:activities, ["(to_tsvector('english', data->'object'->>'content'))"],
        using: :gin,
        name: :activities_fts
      )
    )

    create_if_not_exists(
      index(:objects, ["(to_tsvector('english', data->>'content'))"],
        using: :gin,
        name: :objects_fts
      )
    )
  end
end
