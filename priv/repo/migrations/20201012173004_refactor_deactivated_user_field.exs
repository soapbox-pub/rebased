# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RefactorDeactivatedUserField do
  use Ecto.Migration

  def up do
    # Flip the values before we change the meaning of the column
    execute("UPDATE users SET deactivated = NOT deactivated;")
    execute("ALTER TABLE users RENAME COLUMN deactivated TO is_active;")
    execute("ALTER TABLE users ALTER COLUMN is_active SET DEFAULT true;")
    execute("ALTER INDEX users_deactivated_index RENAME TO users_is_active_index;")
  end

  def down do
    execute("UPDATE users SET is_active = NOT is_active;")
    execute("ALTER TABLE users RENAME COLUMN is_active TO deactivated;")
    execute("ALTER TABLE users ALTER COLUMN deactivated SET DEFAULT false;")
    execute("ALTER INDEX users_is_active_index RENAME TO users_deactivated_index;")
  end
end
