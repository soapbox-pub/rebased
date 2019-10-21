defmodule Pleroma.Repo.Migrations.MigrateFollowingRelationships do
  use Ecto.Migration

  def change do
    execute(import_following_from_users(), "")
    execute(import_following_from_activities(), restore_following_column())
  end

  defp import_following_from_users do
    """
    INSERT INTO following_relationships (follower_id, following_id, state, inserted_at, updated_at)
    SELECT
        relations.follower_id,
        following.id,
        'accept',
        now(),
        now()
    FROM (
        SELECT
            users.id AS follower_id,
            unnest(users.following) AS following_ap_id
        FROM
            users
        WHERE
            users.following != '{}'
            AND users.local = false OR users.local = true AND users.email IS NOT NULL -- Exclude `internal/fetch` and `relay`
    ) AS relations
        JOIN users AS "following" ON "following".follower_address = relations.following_ap_id

        WHERE relations.follower_id != following.id
    ON CONFLICT DO NOTHING
    """
  end

  defp import_following_from_activities do
    """
    INSERT INTO
        following_relationships (
            follower_id,
            following_id,
            state,
            inserted_at,
            updated_at
        )
    SELECT
        followers.id,
        following.id,
        activities.data ->> 'state',
        (activities.data ->> 'published') :: timestamp,
        now()
    FROM
        activities
        JOIN users AS followers ON (activities.actor = followers.ap_id)
        JOIN users AS following ON (activities.data ->> 'object' = following.ap_id)
    WHERE
        activities.data ->> 'type' = 'Follow'
        AND activities.data ->> 'state' IN ('accept', 'pending', 'reject')
    ORDER BY activities.updated_at DESC
    ON CONFLICT DO NOTHING
    """
  end

  defp restore_following_column do
    """
    UPDATE
        users
    SET
        following = following_query.following_array,
        updated_at = now()
    FROM (
        SELECT
            follower.id AS follower_id,
            CASE follower.local
            WHEN TRUE THEN
                array_prepend(follower.follower_address, array_agg(following.follower_address))
            ELSE
                array_agg(following.follower_address)
            END AS following_array
        FROM
            following_relationships
            JOIN users AS follower ON follower.id = following_relationships.follower_id
            JOIN users AS following ON following.id = following_relationships.following_id
        GROUP BY
            follower.id) AS following_query
    WHERE
        following_query.follower_id = users.id
    """
  end
end
