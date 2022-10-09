defmodule Pleroma.Repo.Migrations.AddActivitiesTypeIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(
      index(:activities, ["(data->>'type')"],
        name: :activities_type,
        concurrently: true
      )
    )
  end
end
