defmodule Pleroma.Repo.Migrations.RemoveTeslaFromConfig do
  use Ecto.Migration

  def up do
    execute("DELETE FROM config WHERE config.group = ':tesla'")
  end

  def down do
  end
end
