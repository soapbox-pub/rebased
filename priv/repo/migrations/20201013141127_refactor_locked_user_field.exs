# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RefactorLockedUserField do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users RENAME COLUMN locked TO is_locked;")
  end

  def down do
    execute("ALTER TABLE users RENAME COLUMN is_locked TO locked;")
  end
end
