defmodule Pleroma.Repo.Migrations.AddFTSIndexToActivities do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["(to_tsvector('english', data->'object'->>'content'))"],
        concurrently: true,
        using: :gin,
        name: :activities_fts
      )
    )
  end
end
