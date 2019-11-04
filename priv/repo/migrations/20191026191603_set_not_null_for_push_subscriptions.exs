defmodule Pleroma.Repo.Migrations.SetNotNullForPushSubscriptions do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE push_subscriptions
    ALTER COLUMN user_id SET NOT NULL,
    ALTER COLUMN token_id SET NOT NULL,
    ALTER COLUMN endpoint SET NOT NULL,
    ALTER COLUMN key_p256dh SET NOT NULL,
    ALTER COLUMN key_auth SET NOT NULL,
    ALTER COLUMN data SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE push_subscriptions
    ALTER COLUMN user_id DROP NOT NULL,
    ALTER COLUMN token_id DROP NOT NULL,
    ALTER COLUMN endpoint DROP NOT NULL,
    ALTER COLUMN key_p256dh DROP NOT NULL,
    ALTER COLUMN key_auth DROP NOT NULL,
    ALTER COLUMN data DROP NOT NULL")
  end
end
