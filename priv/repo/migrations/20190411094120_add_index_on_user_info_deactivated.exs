defmodule Pleroma.Repo.Migrations.AddIndexOnUserInfoDeactivated do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:users, ["(info->'deactivated')"], name: :users_deactivated_index, using: :gin)
    )
  end
end
