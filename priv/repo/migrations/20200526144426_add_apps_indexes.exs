# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddAppsIndexes do
  use Ecto.Migration

  def change do
    create(index(:apps, [:client_id, :client_secret]))
  end
end
