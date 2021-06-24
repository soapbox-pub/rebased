defmodule Pleroma.Repo.Migrations.AddApIdToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add(:ap_id, :string, null: false)
    end

    create_if_not_exists(unique_index(:groups, [:ap_id]))
  end
end
