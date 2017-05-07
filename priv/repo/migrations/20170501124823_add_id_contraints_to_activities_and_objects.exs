defmodule Pleroma.Repo.Migrations.AddIdContraintsToActivitiesAndObjects do
  use Ecto.Migration

  def change do
    create index(:objects, ["(data->>\"id\")"], name: :objects_unique_apid_index)
    create index(:activities, ["(data->>\"id\")"], name: :activities_unique_apid_index)
  end
end
