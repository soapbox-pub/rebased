defmodule Pleroma.Repo.Migrations.AddPermitFollowback do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:permit_followback, :boolean, null: false, default: false)
    end
  end
end
