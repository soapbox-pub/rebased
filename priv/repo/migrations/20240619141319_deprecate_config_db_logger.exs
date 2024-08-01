defmodule Pleroma.Repo.Migrations.DeprecateConfigDBLogger do
  use Ecto.Migration

  def change do
    execute("DELETE FROM config WHERE config.group = ':logger'")
  end
end
