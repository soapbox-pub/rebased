# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.BackfillNotificationTypes do
  use Ecto.Migration

  def up do
    Pleroma.MigrationHelper.NotificationBackfill.fill_in_notification_types()
  end

  def down do
  end
end
