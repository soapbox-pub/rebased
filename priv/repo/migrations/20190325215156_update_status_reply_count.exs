defmodule Pleroma.Repo.Migrations.UpdateStatusReplyCount do
  use Ecto.Migration

  @public "https://www.w3.org/ns/activitystreams#Public"

  def up do
    execute("""
      WITH reply_count AS (
        SELECT count(*) AS count, data->>'inReplyTo' AS ap_id
        FROM objects
        WHERE
          data->>'inReplyTo' IS NOT NULL AND
          data->>'type' = 'Note' AND (
            data->'cc' ? '#{@public}' OR
            data->'to' ? '#{@public}')
        GROUP BY data->>'inReplyTo'
      )
      UPDATE objects AS o
      SET "data" = jsonb_set(o.data, '{repliesCount}', reply_count.count::varchar::jsonb, true)
      FROM reply_count
      WHERE reply_count.ap_id = o.data->>'id';
    """)

    execute("""
      WITH reply_count AS (SELECT
          count(*) as count,
          data->'object'->>'inReplyTo' AS ap_id
        FROM
          activities
        WHERE
          data->'object'->>'inReplyTo' IS NOT NULL AND
          data->'object'->>'type' = 'Note' AND (
            data->'object'->'cc' ? '#{@public}' OR
            data->'object'->'to' ? '#{@public}')
        GROUP BY
          data->'object'->>'inReplyTo'
      )
      UPDATE activities AS a
      SET "data" = jsonb_set(a.data, '{object, repliesCount}', reply_count.count::varchar::jsonb, true)
      FROM reply_count
      WHERE reply_count.ap_id = a.data->'object'->>'id';
    """)
  end

  def down do
    :noop
  end
end
