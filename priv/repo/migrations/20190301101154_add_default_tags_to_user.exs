# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddDefaultTagsToUser do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET tags = array[]::varchar[] where tags IS NULL")
  end

  def down, do: :noop
end
