# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20221128103145_add_per_user_post_expiry.exs

defmodule Pleroma.Repo.Migrations.AddPerUserPostExpiry do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:status_ttl_days, :integer, null: true)
    end
  end
end
