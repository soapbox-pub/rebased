# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DropObjectIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:objects, [:data], using: :gin))
  end
end
