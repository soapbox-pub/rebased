defmodule Pleroma.Repo.Migrations.CopyMutedToMutedNotifications do
  use Ecto.Migration

  def change do
    execute(
      "update users set info = safe_jsonb_set(info, '{muted_notifications}', info->'mutes', true) where local = true"
    )
  end
end
