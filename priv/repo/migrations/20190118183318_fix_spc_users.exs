defmodule Pleroma.Repo.Migrations.FixSPCUsers do
  use Ecto.Migration

  def up do
    Pleroma.SpcFixes.upgrade_users()
  end

  def down do
  end
end
