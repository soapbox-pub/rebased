defmodule Pleroma.Repo.Migrations.CopyMutedToMutedNotifications do
  use Ecto.Migration
  alias Pleroma.User

  def change do
  execute("update users set info = jsonb_set(info, '{muted_notifications}', info->'mutes', true) where local = true")
  end
end
