# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameInstanceChat do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  def up, do: :noop
  def down, do: :noop
end
