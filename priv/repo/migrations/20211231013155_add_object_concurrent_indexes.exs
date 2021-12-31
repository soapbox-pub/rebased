defmodule Pleroma.Repo.Migrations.AddObjectConcurrentIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(
      index(:objects, ["activity_visibility(actor, recipients, data)", "id DESC NULLS LAST"],
        name: :objects_visibility_index,
        concurrently: true,
        where: "data->>'type' = 'Create'"
      )
    )
  end
end
