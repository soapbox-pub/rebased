defmodule Pleroma.Repo.Migrations.CreatePleroma.Activity do
  use Ecto.Migration

  def change do
    create table(:activities) do
      add :data, :map

      timestamps()
    end

    create index(:activities, [:data], using: :gin)

  end
end
