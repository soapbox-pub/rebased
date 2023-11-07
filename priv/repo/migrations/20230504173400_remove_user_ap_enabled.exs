# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveUserApEnabled do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:ap_enabled, :boolean, default: false, null: false)
    end
  end
end
