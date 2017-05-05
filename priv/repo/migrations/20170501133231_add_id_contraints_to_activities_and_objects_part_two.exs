defmodule Pleroma.Repo.Migrations.AddIdContraintsToActivitiesAndObjectsPartTwo do
  use Ecto.Migration

  def change do
    drop index(:objects, ["(data->>\"id\")"], name: :objects_unique_apid_index)
    drop index(:activities, ["(data->>\"id\")"], name: :activities_unique_apid_index)
    create unique_index(:objects, ["(data->>'id')"], name: :objects_unique_apid_index)
    create unique_index(:activities, ["(data->>'id')"], name: :activities_unique_apid_index)
  end
end
