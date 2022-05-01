# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.BioSetNotNull do
  use Ecto.Migration

  def change do
    execute(
      "alter table users alter column bio set not null",
      "alter table users alter column bio drop not null"
    )
  end
end
