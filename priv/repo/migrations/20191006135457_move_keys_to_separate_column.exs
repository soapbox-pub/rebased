# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MoveKeysToSeparateColumn do
  use Ecto.Migration

  def change do
    execute(
      "update users set keys = info->>'keys' where local",
      "update users set info = jsonb_set(info, '{keys}'::text[], to_jsonb(keys)) where local"
    )
  end
end
