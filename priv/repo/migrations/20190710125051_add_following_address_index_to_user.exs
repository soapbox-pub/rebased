defmodule Pleroma.Repo.Migrations.AddFollowingAddressIndexToUser do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(index(:users, [:following_address], concurrently: true))
  end
end
