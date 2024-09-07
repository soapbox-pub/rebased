# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20220108213213_add_mastofe_settings.exs

defmodule Pleroma.Repo.Migrations.AddMastofeSettings do
  use Ecto.Migration

  def up, do: :ok

  def down do
    alter table(:users) do
      remove_if_exists(:mastofe_settings, :map)
    end
  end
end
