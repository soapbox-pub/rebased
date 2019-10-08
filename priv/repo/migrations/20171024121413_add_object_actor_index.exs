defmodule Pleroma.Repo.Migrations.AddObjectActorIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(
      index(:objects, ["(data->>'actor')", "(data->>'type')"],
        concurrently: true,
        name: :objects_actor_type
      )
    )
  end
end
