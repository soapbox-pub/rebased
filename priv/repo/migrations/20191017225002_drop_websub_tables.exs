# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DropWebsubTables do
  use Ecto.Migration

  def up do
    drop_if_exists(table(:websub_client_subscriptions))
    drop_if_exists(table(:websub_server_subscriptions))
  end

  def down, do: :noop
end
