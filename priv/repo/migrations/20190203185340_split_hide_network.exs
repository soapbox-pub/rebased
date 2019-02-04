defmodule Pleroma.Repo.Migrations.SplitHideNetwork do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET info = '{\"hide_network\": false}'::jsonb WHERE NOT(info::jsonb ? 'hide_network')")
    execute("UPDATE users SET info = jsonb_set(info, '{hide_followings}'::text[], info->'hide_network')")
    execute("UPDATE users SET info = jsonb_set(info, '{hide_followers}'::text[], info->'hide_network')")
  end

  def down do
  end
end
