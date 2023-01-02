# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.EnsureBioIsString do
  use Ecto.Migration

  def change do
    execute("update users set bio = '' where bio is null", "")
  end
end
