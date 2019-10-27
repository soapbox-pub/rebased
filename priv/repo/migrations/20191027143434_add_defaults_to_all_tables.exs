defmodule Pleroma.Repo.Migrations.AddDefaultsToAllTables do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE activities
    ALTER COLUMN recipients SET DEFAULT ARRAY[]::character varying[]")

    execute("ALTER TABLE filters
    ALTER COLUMN whole_word SET DEFAULT true")

    execute("ALTER TABLE push_subscriptions
    ALTER COLUMN data SET DEFAULT '{}'::jsonb")

    execute(~s(ALTER TABLE users
    ALTER COLUMN following SET DEFAULT ARRAY[]::character varying[],
    ALTER COLUMN tags SET DEFAULT ARRAY[]::character varying[],
    ALTER COLUMN notification_settings SET DEFAULT
      '{"followers": true, "follows": true, "non_follows": true, "non_followers": true}'::jsonb))

    # irreversible updates

    execute(
      "UPDATE activities SET recipients = ARRAY[]::character varying[] WHERE recipients IS NULL"
    )

    execute("UPDATE filters SET whole_word = true WHERE whole_word IS NULL")

    execute("UPDATE push_subscriptions SET data = '{}'::jsonb WHERE data IS NULL")

    execute("UPDATE users SET following = ARRAY[]::character varying[] WHERE following IS NULL")
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
    ALTER COLUMN following DROP DEFAULT,
    ALTER COLUMN tags DROP DEFAULT,
    ALTER COLUMN notification_settings SET DEFAULT '{}'::jsonb")
  end
end
