defmodule Pleroma.Repo.Migrations.AddActivitiesLikesIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["((data #> '{\"object\",\"likes\"}'))"],
        concurrently: true,
        name: :activities_likes,
        using: :gin
      )
    )
  end
end
