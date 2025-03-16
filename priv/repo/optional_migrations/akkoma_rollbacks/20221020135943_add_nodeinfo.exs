# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20221020135943_add_nodeinfo.exs

defmodule Pleroma.Repo.Migrations.AddNodeinfo do
  use Ecto.Migration

  def up, do: :ok

  def down do
    alter table(:instances) do
      remove_if_exists(:nodeinfo, :map)
      remove_if_exists(:metadata_updated_at, :naive_datetime)
    end
  end
end
