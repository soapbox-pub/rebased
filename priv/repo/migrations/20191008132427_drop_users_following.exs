defmodule Pleroma.Repo.Migrations.DropUsersFollowing do
  use Ecto.Migration

  # had to disable these to be able to restore `following` index concurrently
  # https://hexdocs.pm/ecto_sql/Ecto.Migration.html#index/3-adding-dropping-indexes-concurrently
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop(index(:users, [:following], concurrently: true, using: :gin))

    alter table(:users) do
      remove(:following, {:array, :string}, default: [])
    end
  end
end
