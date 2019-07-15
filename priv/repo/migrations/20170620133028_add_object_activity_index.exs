defmodule Pleroma.Repo.Migrations.AddObjectActivityIndex do
  use Ecto.Migration

  def change do
    # This was wrong, now a noop
    # create_if_not_exists index(:objects, ["(data->'object'->>'id')", "(data->>'type')"], name: :activities_create_objects_index)
  end
end
