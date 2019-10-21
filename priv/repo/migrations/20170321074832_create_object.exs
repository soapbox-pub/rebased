defmodule Pleroma.Repo.Migrations.CreatePleroma.Object do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:objects) do
      add(:data, :map)

      timestamps()
    end
  end
end
