defmodule Pleroma.Repo.Migrations.CreateConfig do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:config) do
      add(:key, :string)
      add(:value, :binary)
      timestamps()
    end

    create_if_not_exists(unique_index(:config, :key))
  end
end
