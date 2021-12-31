defmodule Pleroma.Repo.Migrations.AddObjectConcurrentIndexes do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(index(:objects, [:actor, "id DESC NULLS LAST"], concurrently: true))

    create_if_not_exists(
      index(:objects, ["(data->>'type')", "(data->>'context')"],
        name: :objects_context_index,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:objects, ["(split_part(actor, '/', 3))"],
        concurrently: true,
        name: :objects_hosts
      )
    )

    create_if_not_exists(index(:objects, ["id desc nulls last", "local"], concurrently: true))

    create_if_not_exists(
      index(:objects, ["activity_visibility(actor, recipients, data)", "id DESC NULLS LAST"],
        name: :objects_visibility_index,
        concurrently: true,
        where: "data->>'type' = 'Create'"
      )
    )

    create_if_not_exists(
      index(:objects, ["(coalesce(data->'object'->>'id', data->>'object'))"],
        name: :objects_create_objects_index,
        concurrently: true
      )
    )
  end
end
