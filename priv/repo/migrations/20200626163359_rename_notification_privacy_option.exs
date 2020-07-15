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
