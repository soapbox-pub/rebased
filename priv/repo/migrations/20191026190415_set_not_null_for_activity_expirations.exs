defmodule Pleroma.Repo.Migrations.SetNotNullForActivityExpirations do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE activity_expirations
    ALTER COLUMN activity_id SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE activity_expirations
    ALTER COLUMN activity_id DROP NOT NULL")
  end
end
