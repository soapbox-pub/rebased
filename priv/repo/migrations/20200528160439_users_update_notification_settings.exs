defmodule Pleroma.Repo.Migrations.UsersUpdateNotificationSettings do
  use Ecto.Migration

  def up do
    execute(
      "UPDATE users SET notification_settings = notification_settings - 'followers' || jsonb_build_object('from_followers', notification_settings->'followers')
where notification_settings ? 'followers'
and local"
    )

    execute(
      "UPDATE users SET notification_settings = notification_settings - 'follows' || jsonb_build_object('from_following', notification_settings->'follows')
where notification_settings ? 'follows'
and local"
    )

    execute(
      "UPDATE users SET notification_settings = notification_settings - 'non_followers' || jsonb_build_object('from_strangers', notification_settings->'non_followers')
where notification_settings ? 'non_followers'
and local"
    )
  end

  def down do
    execute(
      "UPDATE users SET notification_settings = notification_settings - 'from_followers' || jsonb_build_object('followers', notification_settings->'from_followers')
where notification_settings ? 'from_followers'
and local"
    )

    execute(
      "UPDATE users SET notification_settings = notification_settings - 'from_following' || jsonb_build_object('follows', notification_settings->'from_following')
where notification_settings ? 'from_following'
and local"
    )

    execute(
      "UPDATE users SET notification_settings = notification_settings - 'from_strangers' || jsonb_build_object('non_follows', notification_settings->'from_strangers')
where notification_settings ? 'from_strangers'
and local"
    )
  end
end
