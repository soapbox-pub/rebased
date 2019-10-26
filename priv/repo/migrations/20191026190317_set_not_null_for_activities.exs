defmodule Pleroma.Repo.Migrations.SetNotNullForActivities do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE activities
    ALTER COLUMN data SET NOT NULL,
    ALTER COLUMN local SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE activities
    ALTER COLUMN data DROP NOT NULL,
    ALTER COLUMN local DROP NOT NULL")
  end
end
