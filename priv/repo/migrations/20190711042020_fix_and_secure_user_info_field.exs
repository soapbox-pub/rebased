defmodule Pleroma.Repo.Migrations.FixAndSecureUserInfoField do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET info = '{}'::jsonb WHERE info IS NULL")

    execute("ALTER TABLE users
    ALTER COLUMN info SET NOT NULL
    ")
  end

  def down do
    execute("ALTER TABLE users
    ALTER COLUMN info DROP NOT NULL
    ")
  end
end
