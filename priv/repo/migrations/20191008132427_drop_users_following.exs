defmodule Pleroma.Repo.Migrations.DropUsersFollowing do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop(index(:users, [:following], concurrently: true, using: :gin))

    alter table(:users) do
      remove(:following, {:array, :string}, default: [])
    end
  end
end
