# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddIndexHotspots do
  use Ecto.Migration

  def change do
    # Stop inserts into activities from doing a full-table scan of users:
    create_if_not_exists(index(:users, [:ap_id, "COALESCE(follower_address, '')"]))

    # Change two indexes and a filter recheck into one index scan:
    create_if_not_exists(index(:following_relationships, [:follower_id, :state]))

    create_if_not_exists(index(:notifications, [:user_id, :seen]))
  end
end
