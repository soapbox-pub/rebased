defmodule Pleroma.Repo.Migrations.UsersAddIsAdminIndex do
  use Ecto.Migration

  def change do
    create(index(:users, ["(info->'is_admin')"], name: :users_is_admin_index, using: :gin))
  end
end
