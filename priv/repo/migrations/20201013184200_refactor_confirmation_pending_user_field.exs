# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RefactorConfirmationPendingUserField do
  use Ecto.Migration

  def up do
    # Flip the values before we change the meaning of the column
    execute("UPDATE users SET confirmation_pending = NOT confirmation_pending;")
    execute("ALTER TABLE users RENAME COLUMN confirmation_pending TO is_confirmed;")
    execute("ALTER TABLE users ALTER COLUMN is_confirmed SET DEFAULT true;")
  end

  def down do
    execute("UPDATE users SET is_confirmed = NOT is_confirmed;")
    execute("ALTER TABLE users RENAME COLUMN is_confirmed TO confirmation_pending;")
    execute("ALTER TABLE users ALTER COLUMN confirmation_pending SET DEFAULT false;")
  end
end
