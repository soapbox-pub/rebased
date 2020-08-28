defmodule Pleroma.Repo.Migrations.UsersRemoveSourceData do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove_if_exists(:source_data, :map)
    end
  end

  def down do
    alter table(:users) do
      add_if_not_exists(:source_data, :map, default: %{})
    end
  end
end
