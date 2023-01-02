# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUUIDsToUserInfo do
  use Ecto.Migration

  def up do
    execute("update users set info = jsonb_set(info, '{\"id\"}', to_jsonb(uuid_generate_v4()))")
  end

  def down, do: :ok
end
