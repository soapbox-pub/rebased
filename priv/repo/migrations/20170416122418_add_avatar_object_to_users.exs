defmodule Pleroma.Repo.Migrations.AddAvatarObjectToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:avatar, :map)
    end
  end
end
