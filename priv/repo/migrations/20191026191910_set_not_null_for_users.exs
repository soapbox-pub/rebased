defmodule Pleroma.Repo.Migrations.SetNotNullForUsers do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    # irreversible
    execute("UPDATE users SET follower_count = 0 WHERE follower_count IS NULL")

    execute("ALTER TABLE users
    ALTER COLUMN following SET NOT NULL,
    ALTER COLUMN local SET NOT NULL,
    ALTER COLUMN source_data SET NOT NULL,
    ALTER COLUMN note_count SET NOT NULL,
    ALTER COLUMN follower_count SET NOT NULL,
    ALTER COLUMN blocks SET NOT NULL,
    ALTER COLUMN domain_blocks SET NOT NULL,
    ALTER COLUMN mutes SET NOT NULL,
    ALTER COLUMN muted_reblogs SET NOT NULL,
    ALTER COLUMN muted_notifications SET NOT NULL,
    ALTER COLUMN subscribers SET NOT NULL,
    ALTER COLUMN pinned_activities SET NOT NULL,
    ALTER COLUMN emoji SET NOT NULL,
    ALTER COLUMN fields SET NOT NULL,
    ALTER COLUMN raw_fields SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE users
    ALTER COLUMN following DROP NOT NULL,
    ALTER COLUMN local DROP NOT NULL,
    ALTER COLUMN source_data DROP NOT NULL,
    ALTER COLUMN note_count DROP NOT NULL,
    ALTER COLUMN follower_count DROP NOT NULL,
    ALTER COLUMN blocks DROP NOT NULL,
    ALTER COLUMN domain_blocks DROP NOT NULL,
    ALTER COLUMN mutes DROP NOT NULL,
    ALTER COLUMN muted_reblogs DROP NOT NULL,
    ALTER COLUMN muted_notifications DROP NOT NULL,
    ALTER COLUMN subscribers DROP NOT NULL,
    ALTER COLUMN pinned_activities DROP NOT NULL,
    ALTER COLUMN emoji DROP NOT NULL,
    ALTER COLUMN fields DROP NOT NULL,
    ALTER COLUMN raw_fields DROP NOT NULL")
  end
end
