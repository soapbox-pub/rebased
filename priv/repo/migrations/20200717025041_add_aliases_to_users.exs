defmodule Pleroma.Repo.Migrations.AddAliasesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:ap_aliases, {:array, :string}, default: [])
    end
  end
end
