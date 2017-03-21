defmodule Pleroma.Repo.Migrations.CreatePleroma.Object do
  use Ecto.Migration

  def change do
    create table(:objects) do
      add :data, :map

      timestamps()
    end

  end
end
