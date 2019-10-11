defmodule Pleroma.Repo.Migrations.AddTagIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["(data #> '{\"object\",\"tag\"}')"],
        concurrently: true,
        using: :gin,
        name: :activities_tags
      )
    )
  end
end
