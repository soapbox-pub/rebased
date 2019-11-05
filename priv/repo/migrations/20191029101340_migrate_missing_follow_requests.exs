defmodule Pleroma.Repo.Migrations.MigrateMissingFollowingRelationships do
  use Ecto.Migration

  def change do
    execute(import_pending_follows_from_activities(), "")
  end

  defp import_pending_follows_from_activities do
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
        AND activities.data ->> 'state' = 'pending'
    ORDER BY activities.updated_at DESC
    ON CONFLICT DO NOTHING
    """
  end
end
