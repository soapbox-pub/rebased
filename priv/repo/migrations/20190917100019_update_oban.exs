defmodule Pleroma.Repo.Migrations.UpdateOban do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 4)
  end

  def down do
    Oban.Migrations.down(version: 2)
  end
end
