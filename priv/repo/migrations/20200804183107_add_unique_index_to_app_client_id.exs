# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUniqueIndexToAppClientId do
  use Ecto.Migration

  def change do
    create(unique_index(:apps, [:client_id]))
  end
end
