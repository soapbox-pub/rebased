defmodule Pleroma.Repo.Migrations.CreateConfig do
  use Ecto.Migration

  def change do
    create table(:config) do
      add(:key, :string)
      add(:value, :binary)
      timestamps()
    end

    create(unique_index(:config, :key))
  end
end
