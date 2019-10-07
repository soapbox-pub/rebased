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

    execute(insert_following_relationships_rows(), restore_following_column())

    drop(index(:users, [:following], concurrently: true, using: :gin))

    alter table(:users) do
      remove(:following, {:array, :string}, default: [])
    end
  end

  defp insert_following_relationships_rows do
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
        AND activities.data ->> 'state' IN ('accept', 'pending', 'reject') ON CONFLICT DO NOTHING
    """
  end

  defp restore_following_column do
    """
    UPDATE
        users
    SET
        following = following_query.following,
        updated_at = now()
    FROM
        (
            SELECT
                followers.id AS follower_id,
                array_prepend(
                    followers.follower_address,
                    array_agg(DISTINCT following.ap_id) FILTER (
                        WHERE
                            following.ap_id IS NOT NULL
                    )
                ) as following
            FROM
                users AS followers
                LEFT OUTER JOIN activities ON (
                    followers.ap_id = activities.actor
                    AND activities.data ->> 'type' = 'Follow'
                    AND activities.data ->> 'state' IN ('accept', 'pending', 'reject')
                )
                LEFT OUTER JOIN users AS following ON (activities.data ->> 'object' = following.ap_id)
            WHERE
                followers.email IS NOT NULL  -- Exclude `internal/fetch` and `relay`
            GROUP BY
                followers.id,
                followers.ap_id
        ) AS following_query
    WHERE
        following_query.follower_id = users.id;
    """
  end
end
