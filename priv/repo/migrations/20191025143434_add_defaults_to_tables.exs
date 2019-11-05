defmodule Pleroma.Repo.Migrations.AddDefaultsToTables do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE activities
    ALTER COLUMN recipients SET DEFAULT ARRAY[]::character varying[]")

    execute("ALTER TABLE filters
    ALTER COLUMN whole_word SET DEFAULT true")

    execute("ALTER TABLE push_subscriptions
    ALTER COLUMN data SET DEFAULT '{}'::jsonb")

    execute(~s(ALTER TABLE users
    ALTER COLUMN tags SET DEFAULT ARRAY[]::character varying[],
    ALTER COLUMN notification_settings SET DEFAULT
      '{"followers": true, "follows": true, "non_follows": true, "non_followers": true}'::jsonb))

    # irreversible updates

    execute(
      "UPDATE activities SET recipients = ARRAY[]::character varying[] WHERE recipients IS NULL"
    )

    execute("UPDATE filters SET whole_word = true WHERE whole_word IS NULL")

    execute("UPDATE push_subscriptions SET data = '{}'::jsonb WHERE data IS NULL")

    execute("UPDATE users SET source_data = '{}'::jsonb where source_data IS NULL")
    execute("UPDATE users SET note_count = 0 where note_count IS NULL")
    execute("UPDATE users SET background = '{}'::jsonb where background IS NULL")
    execute("UPDATE users SET follower_count = 0 where follower_count IS NULL")

    execute(
      "UPDATE users SET unread_conversation_count = 0 where unread_conversation_count IS NULL"
    )

    execute(
      ~s(UPDATE users SET email_notifications = '{"digest": false}'::jsonb where email_notifications IS NULL)
    )

    execute("UPDATE users SET default_scope = 'public' where default_scope IS NULL")

    execute(
      "UPDATE users SET pleroma_settings_store = '{}'::jsonb where pleroma_settings_store IS NULL"
    )

    execute("UPDATE users SET tags = ARRAY[]::character varying[] WHERE tags IS NULL")
    execute(~s(UPDATE users SET notification_settings =
      '{"followers": true, "follows": true, "non_follows": true, "non_followers": true}'::jsonb
      WHERE notification_settings = '{}'::jsonb))
  end

  def down do
    execute("ALTER TABLE activities
    ALTER COLUMN recipients DROP DEFAULT")

    execute("ALTER TABLE filters
    ALTER COLUMN whole_word DROP DEFAULT")

    execute("ALTER TABLE push_subscriptions
    ALTER COLUMN data DROP DEFAULT")

    execute("ALTER TABLE users
    ALTER COLUMN tags DROP DEFAULT,
    ALTER COLUMN notification_settings SET DEFAULT '{}'::jsonb")
  end
end
