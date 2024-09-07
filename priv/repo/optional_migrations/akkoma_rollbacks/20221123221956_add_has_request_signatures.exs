# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20221123221956_add_has_request_signatures.exs

defmodule Pleroma.Repo.Migrations.AddHasRequestSignatures do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add(:has_request_signatures, :boolean, default: false, null: false)
    end
  end
end
