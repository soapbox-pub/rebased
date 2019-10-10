defmodule Pleroma.Repo.Migrations.UpdateUserNoteCounters do
  use Ecto.Migration

  @public "https://www.w3.org/ns/activitystreams#Public"

  def up do
    execute("""
      WITH public_note_count AS (
        SELECT
          data->>'actor' AS actor,
          count(id) AS count
        FROM objects
        WHERE data->>'type' = 'Note' AND (
          data->'cc' ? '#{@public}' OR data->'to' ? '#{@public}'
        )
        GROUP BY data->>'actor'
      )
      UPDATE users AS u
      SET "info" = jsonb_set(u.info, '{note_count}', o.count::varchar::jsonb, true)
      FROM public_note_count AS o
      WHERE u.ap_id = o.actor
    """)
  end

  def down do
    execute("""
      WITH public_note_count AS (
        SELECT
          data->>'actor' AS actor,
          count(id) AS count
        FROM objects
        WHERE data->>'type' = 'Note'
        GROUP BY data->>'actor'
      )
      UPDATE users AS u
      SET "info" = jsonb_set(u.info, '{note_count}', o.count::varchar::jsonb, true)
      FROM public_note_count AS o
      WHERE u.ap_id = o.actor
    """)
  end
end
