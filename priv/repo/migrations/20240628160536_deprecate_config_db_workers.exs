defmodule Pleroma.Repo.Migrations.DeprecateConfigDBWorkers do
  use Ecto.Migration

  def change do
    execute("DELETE FROM config WHERE config.group = ':workers'")
  end
end
