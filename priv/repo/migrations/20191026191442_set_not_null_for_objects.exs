defmodule Pleroma.Repo.Migrations.SetNotNullForObjects do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE objects
    ALTER COLUMN data SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE objects
    ALTER COLUMN data DROP NOT NULL")
  end
end
