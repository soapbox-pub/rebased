defmodule Pleroma.Repo.Migrations.AddEventsIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:objects, ["(data->>'type')"],
        where: "data->>'type' = 'Event'",
        name: :objects_events,
        concurrently: true
      )
    )
  end
end
