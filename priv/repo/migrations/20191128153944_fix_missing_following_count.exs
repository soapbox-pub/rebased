# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.FixMissingFollowingCount do
  use Ecto.Migration

  def up do
    """
    UPDATE
      users
    SET
      following_count = sub.count
    FROM
      (
        SELECT
          users.id AS sub_id
          ,COUNT (following_relationships.id)
        FROM
          following_relationships
          ,users
        WHERE
          users.id = following_relationships.follower_id
        AND following_relationships.state = 'accept'
        GROUP BY
          users.id
      ) AS sub
    WHERE
      users.id = sub.sub_id
    AND users.local = TRUE
    ;
    """
    |> execute()

    """
    UPDATE
      users
    SET
      following_count = 0
    WHERE
      following_count IS NULL
    """
    |> execute()

    execute("ALTER TABLE users
      ALTER COLUMN following_count SET DEFAULT 0,
      ALTER COLUMN following_count SET NOT NULL
    ")
  end

  def down do
    execute("ALTER TABLE users
      ALTER COLUMN following_count DROP DEFAULT,
      ALTER COLUMN following_count DROP NOT NULL
    ")
  end
end
