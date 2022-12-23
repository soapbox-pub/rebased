# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddSortIndexToActivities do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(index(:activities, ["id desc nulls last"], concurrently: true))
  end
end
