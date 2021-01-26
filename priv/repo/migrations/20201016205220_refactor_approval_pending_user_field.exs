# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RefactorApprovalPendingUserField do
  use Ecto.Migration

  def up do
    # Flip the values before we change the meaning of the column
    execute("UPDATE users SET approval_pending = NOT approval_pending;")
    execute("ALTER TABLE users RENAME COLUMN approval_pending TO is_approved;")
    execute("ALTER TABLE users ALTER COLUMN is_approved SET DEFAULT true;")
  end

  def down do
    execute("UPDATE users SET is_approved = NOT is_approved;")
    execute("ALTER TABLE users RENAME COLUMN is_approved TO approval_pending;")
    execute("ALTER TABLE users ALTER COLUMN approval_pending SET DEFAULT false;")
  end
end
