defmodule Pleroma.Repo.Migrations.SplitHideNetwork do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET info = jsonb_set(jsonb_set(info, '{hide_followers}'::text[], info->'hide_network'), '{hide_followings}'::text[], info->'hide_network')")
  end

  def down do
  end
end
