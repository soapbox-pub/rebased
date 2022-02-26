# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameNotificationPrivacyOption do
  use Ecto.Migration

  def up do
    execute(
      "UPDATE users SET notification_settings = notification_settings - 'privacy_option' || jsonb_build_object('hide_notification_contents', notification_settings->'privacy_option')
where notification_settings ? 'privacy_option'
and local"
    )
  end

  def down do
    execute(
      "UPDATE users SET notification_settings = notification_settings - 'hide_notification_contents' || jsonb_build_object('privacy_option', notification_settings->'hide_notification_contents')
where notification_settings ? 'hide_notification_contents'
and local"
    )
  end
end
