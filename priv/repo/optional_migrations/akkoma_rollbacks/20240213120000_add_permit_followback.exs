# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20240213120000_add_permit_followback.exs

defmodule Pleroma.Repo.Migrations.AddPermitFollowback do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:permit_followback, :boolean, null: false, default: false)
    end
  end
end
