defmodule Pleroma.Repo.Migrations.AddListFollowIndex do
  use Ecto.Migration

  def change do
    create index(:lists, [:following])
  end
end
