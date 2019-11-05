defmodule Pleroma.Repo.Migrations.FixNullMutedNotificationFields do
  use Ecto.Migration

  def change do
    execute("update users set info = safe_jsonb_set(info, '{muted_notifications}', '[]'::jsonb, true) where local = true and info->'muted_notifications' = 'null'::jsonb")
  end
end
