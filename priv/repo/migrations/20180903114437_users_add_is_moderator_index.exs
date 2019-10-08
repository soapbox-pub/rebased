defmodule Pleroma.Repo.Migrations.UsersAddIsModeratorIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:users, ["(info->'is_moderator')"], name: :users_is_moderator_index, using: :gin)
    )
  end
end
