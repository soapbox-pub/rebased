defmodule Pleroma.Repo.Migrations.SetDefaultStateToReports do
  use Ecto.Migration

  def up do
    execute("""
      UPDATE activities AS a
      SET data = jsonb_set(data, '{state}', '"open"', true)
      WHERE data->>'type' = 'Flag'
    """)
  end

  def down do
    execute("""
      UPDATE activities AS a
      SET data = data #- '{state}'
      WHERE data->>'type' = 'Flag'
    """)
  end
end
