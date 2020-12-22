defmodule Pleroma.Repo.Migrations.CreateHashtags do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:hashtags) do
      add(:name, :citext, null: false)
      add(:data, :map, default: %{})

      timestamps()
    end

    create_if_not_exists(unique_index(:hashtags, [:name]))
  end
end
