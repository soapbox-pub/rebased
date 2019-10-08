defmodule Pleroma.Repo.Migrations.CreateInstances do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:instances) do
      add(:host, :string)
      add(:unreachable_since, :naive_datetime_usec)

      timestamps()
    end

    create_if_not_exists(unique_index(:instances, [:host]))
    create_if_not_exists(index(:instances, [:unreachable_since]))
  end
end
