# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUUIDExtension do
  use Ecto.Migration

  def up do
    execute("create extension if not exists \"uuid-ossp\"")
  end

  def down, do: :ok
end
