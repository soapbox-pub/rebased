defmodule Pleroma.Repo.Migrations.AddFollowerAddressIndexToUsers do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(index(:users, [:follower_address], concurrently: true))
    create(index(:users, [:following], concurrently: true, using: :gin))
  end
end
