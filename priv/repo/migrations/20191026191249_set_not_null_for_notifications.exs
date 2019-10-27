defmodule Pleroma.Repo.Migrations.SetNotNullForNotifications do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE notifications
    ALTER COLUMN user_id SET NOT NULL,
    ALTER COLUMN seen SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE notifications
    ALTER COLUMN user_id DROP NOT NULL,
    ALTER COLUMN seen DROP NOT NULL")
  end
end
