defmodule Pleroma.Repo.Migrations.AddLocationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:location, :string)
    end
  end
end
