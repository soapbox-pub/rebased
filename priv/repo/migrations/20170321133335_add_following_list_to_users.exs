defmodule Pleroma.Repo.Migrations.AddFollowingListToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:following, :map)
    end
  end
end
