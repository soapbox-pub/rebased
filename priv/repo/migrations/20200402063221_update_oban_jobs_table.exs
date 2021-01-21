defmodule Pleroma.Repo.Migrations.UpdateObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 8)
  end

  def down do
    Oban.Migrations.down(version: 8)
  end
end
