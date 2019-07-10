defmodule Pleroma.Repo.Migrations.AddFollowingAddressToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:following_address, :string, unique: true)
    end
  end
end
