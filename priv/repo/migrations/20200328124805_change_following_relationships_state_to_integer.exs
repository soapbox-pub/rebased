# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChangeFollowingRelationshipsStateToInteger do
  use Ecto.Migration

  @alter_following_relationship_state "ALTER TABLE following_relationships ALTER COLUMN state"

  def up do
    execute("""
    #{@alter_following_relationship_state} TYPE integer USING
    CASE
      WHEN state = 'pending' THEN 1
      WHEN state = 'accept' THEN 2
      WHEN state = 'reject' THEN 3
      ELSE 0
    END;
    """)
  end

  def down do
    execute("""
    #{@alter_following_relationship_state} TYPE varchar(255) USING
    CASE
      WHEN state = 1 THEN 'pending'
      WHEN state = 2 THEN 'accept'
      WHEN state = 3 THEN 'reject'
      ELSE ''
    END;
    """)
  end
end
