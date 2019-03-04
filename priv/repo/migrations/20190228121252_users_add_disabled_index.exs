defmodule Pleroma.Repo.Migrations.UsersAddDisabledIndex do
  use Ecto.Migration

  def change do
    create(index(:users, ["(info->'disabled')"], name: :users_disabled_index, using: :gin))
  end
end
