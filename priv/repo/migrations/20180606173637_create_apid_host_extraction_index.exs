# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateApidHostExtractionIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["(split_part(actor, '/', 3))"],
        concurrently: true,
        name: :activities_hosts
      )
    )
  end
end
