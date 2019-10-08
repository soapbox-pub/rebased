defmodule Pleroma.Repo.Migrations.CreateFollowingRelationships do
  use Ecto.Migration

  # had to disable these to be able to restore `following` index concurrently
  # https://hexdocs.pm/ecto_sql/Ecto.Migration.html#index/3-adding-dropping-indexes-concurrently
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists table(:following_relationships) do
      add(:follower_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:following_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:state, :string, null: false)

      timestamps()
    end

    create_if_not_exists(index(:following_relationships, :follower_id))
    create_if_not_exists(unique_index(:following_relationships, [:follower_id, :following_id]))

    execute(import_following_from_users(), "")
    execute(import_following_from_activities(), restore_following_column())

    drop(index(:users, [:following], concurrently: true, using: :gin))

    alter table(:users) do
      remove(:following, {:array, :string}, default: [])
    end
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
            follwer.id AS follower_id,
            CASE follwer.local
            WHEN TRUE THEN
                array_prepend(follwer.follower_address, array_agg(following.follower_address))
            ELSE
                array_agg(following.follower_address)
            END AS following_array
        FROM
            following_relationships
            JOIN users AS follwer ON follwer.id = following_relationships.follower_id
            JOIN users AS FOLLOWING ON following.id = following_relationships.following_id
        GROUP BY
            follwer.id) AS following_query
    WHERE
        following_query.follower_id = users.id
    """
  end
end
