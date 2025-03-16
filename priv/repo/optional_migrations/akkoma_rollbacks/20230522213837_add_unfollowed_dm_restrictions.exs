# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20230522213837_add_unfollowed_dm_restrictions.exs

defmodule Pleroma.Repo.Migrations.AddUnfollowedDmRestrictions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_direct_messages_from, :string, default: "everybody")
    end
  end
end
