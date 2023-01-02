# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddNonFollowsAndNonFollowersFieldsToNotificationSettings do
  use Ecto.Migration

  def up do
    execute("""
    update users set info = jsonb_set(info, '{notification_settings}', '{"local": true, "remote": true, "follows": true, "followers": true, "non_follows": true, "non_followers": true}')
    where local=true
    """)
  end

  def down, do: :ok
end
