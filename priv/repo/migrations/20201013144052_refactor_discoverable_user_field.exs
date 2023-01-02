# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RefactorDiscoverableUserField do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users RENAME COLUMN discoverable TO is_discoverable;")
  end

  def down do
    execute("ALTER TABLE users RENAME COLUMN is_discoverable TO discoverable;")
  end
end
