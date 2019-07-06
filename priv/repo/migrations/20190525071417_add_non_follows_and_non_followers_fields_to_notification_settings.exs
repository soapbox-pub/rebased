defmodule Pleroma.Repo.Migrations.AddNonFollowsAndNonFollowersFieldsToNotificationSettings do
  use Ecto.Migration

  def up do
    execute("""
    update users set info = jsonb_set(info, '{notification_settings}', '{"local": true, "remote": true, "follows": true, "followers": true, "non_follows": true, "non_followers": true}')
    where local=true
    """)
  end

  def down, do: :ok
end
