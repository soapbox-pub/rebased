# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddNotificationConstraints do
  use Ecto.Migration

  def up do
    drop(constraint(:notifications, "notifications_activity_id_fkey"))

    alter table(:notifications) do
      modify(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all),
        null: false
      )
    end
  end

  def down do
    drop(constraint(:notifications, "notifications_activity_id_fkey"))

    alter table(:notifications) do
      modify(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all),
        null: true
      )
    end
  end
end
