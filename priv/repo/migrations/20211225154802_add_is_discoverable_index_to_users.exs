# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddIsDiscoverableIndexToUsers do
  use Ecto.Migration

  def change do
    create(index(:users, [:is_discoverable]))
  end
end
