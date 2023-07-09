# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DropSubscriptionIfExists do
  use Ecto.Migration

  def change do
  end

  def up do
    drop_if_exists(index(:subscription_notifications, [:user_id]))
    drop_if_exists(index(:subscription_notifications, ["id desc nulls last"]))
    drop_if_exists(table(:subscription_notifications))
  end

  def down do
    :ok
  end
end
