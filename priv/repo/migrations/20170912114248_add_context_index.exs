# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddContextIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["(data->>'type')", "(data->>'context')"],
        name: :activities_context_index,
        concurrently: true
      )
    )
  end
end
