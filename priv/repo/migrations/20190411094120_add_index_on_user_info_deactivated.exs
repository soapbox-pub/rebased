defmodule Pleroma.Repo.Migrations.AddIndexOnUserInfoDeactivated do
  use Ecto.Migration

  def change do
    create(index(:users, ["(info->'deactivated')"], name: :users_deactivated_index, using: :gin))
  end
end
