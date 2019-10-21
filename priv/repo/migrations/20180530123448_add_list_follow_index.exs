defmodule Pleroma.Repo.Migrations.AddListFollowIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:lists, [:following]))
  end
end
