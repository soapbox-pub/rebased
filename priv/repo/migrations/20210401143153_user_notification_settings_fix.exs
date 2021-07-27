defmodule Pleroma.Repo.Migrations.UserNotificationSettingsFix do
  use Ecto.Migration

  def up do
    execute(~s(UPDATE users
    SET 
      notification_settings = '{"followers": true, "follows": true, "non_follows": true, "non_followers": true}'::jsonb WHERE notification_settings IS NULL
))

    execute("ALTER TABLE users
    ALTER COLUMN notification_settings SET NOT NULL")
  end

  def down do
    :ok
  end
end
