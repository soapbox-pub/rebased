# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CopyMutedToMutedNotifications do
  use Ecto.Migration

  def change do
    execute("update users set info = '{}' where info is null")

    execute(
      "update users set info = safe_jsonb_set(info, '{muted_notifications}', info->'mutes', true) where local = true"
    )
  end
end
