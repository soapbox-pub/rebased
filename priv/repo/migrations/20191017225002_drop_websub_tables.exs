defmodule Pleroma.Repo.Migrations.DropWebsubTables do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:websub_client_subscriptions))
    drop_if_exists(table(:websub_server_subscriptions))
  end
end
