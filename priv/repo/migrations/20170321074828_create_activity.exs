defmodule Pleroma.Repo.Migrations.CreatePleroma.Activity do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:activities) do
      add(:data, :map)

      timestamps()
    end

    create_if_not_exists(index(:activities, [:data], using: :gin))
  end
end
