defmodule Pleroma.Repo.Migrations.ActivitiesAddToCcIndices do
  use Ecto.Migration

  def change do
    create index(:activities, ["(data->'to')"], name: :activities_to_index, using: :gin)
    create index(:activities, ["(data->'cc')"], name: :activities_cc_index, using: :gin)
  end
end
