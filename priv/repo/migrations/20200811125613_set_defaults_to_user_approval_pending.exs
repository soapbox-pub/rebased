# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.SetDefaultsToUserApprovalPending do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET approval_pending = false WHERE approval_pending IS NULL")

    alter table(:users) do
      modify(:approval_pending, :boolean, default: false, null: false)
    end
  end

  def down do
    :ok
  end
end
