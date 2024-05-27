# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
