defmodule Pleroma.Repo.Migrations.AddObjectActivityIndexPartTwo do
  use Ecto.Migration

  def change do
    drop_if_exists index(:objects, ["(data->'object'->>'id')", "(data->>'type')"], name: :activities_create_objects_index)
    create index(:activities, ["(data->'object'->>'id')", "(data->>'type')"], name: :activities_create_objects_index)
  end
end
