# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.SetNotNullForRegistrations do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE registrations
    ALTER COLUMN provider SET NOT NULL,
    ALTER COLUMN uid SET NOT NULL,
    ALTER COLUMN info SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE registrations
    ALTER COLUMN provider DROP NOT NULL,
    ALTER COLUMN uid DROP NOT NULL,
    ALTER COLUMN info DROP NOT NULL")
  end
end
