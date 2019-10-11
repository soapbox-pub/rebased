defmodule Pleroma.Repo.Migrations.AddFollowerAddressToUser do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:follower_address, :string, unique: true)
    end
  end

  def down do
    alter table(:users) do
      remove(:follower_address)
    end
  end
end
