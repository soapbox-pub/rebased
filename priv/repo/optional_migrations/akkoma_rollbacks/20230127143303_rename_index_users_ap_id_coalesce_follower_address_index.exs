# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20230127143303_rename_index_users_ap_id_coalesce_follower_address_index.exs

defmodule Pleroma.Repo.Migrations.RenameIndexUsersApId_COALESCEFollowerAddressIndex do
  alias Pleroma.Repo

  use Ecto.Migration

  def up, do: :ok

  def down do
    Repo.query!("ALTER INDEX public.\"aa_users_ap_id_COALESCE_follower_address_index\"
    RENAME TO \"users_ap_id_COALESCE_follower_address_index\";")
  end
end
