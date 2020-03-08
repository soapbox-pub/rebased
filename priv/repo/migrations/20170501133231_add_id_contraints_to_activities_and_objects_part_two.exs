defmodule Pleroma.Repo.Migrations.AddIdContraintsToActivitiesAndObjectsPartTwo do
  use Ecto.Migration

  def up do
    drop_if_exists(index(:objects, ["(data->>\"id\")"], name: :objects_unique_apid_index))
    drop_if_exists(index(:activities, ["(data->>\"id\")"], name: :activities_unique_apid_index))

    create_if_not_exists(
      unique_index(:objects, ["(data->>'id')"], name: :objects_unique_apid_index)
    )

    create_if_not_exists(
      unique_index(:activities, ["(data->>'id')"], name: :activities_unique_apid_index)
    )
  end

  def down, do: :ok
end
