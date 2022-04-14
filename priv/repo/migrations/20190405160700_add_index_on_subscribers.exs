# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddIndexOnSubscribers do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(
      index(:users, ["(info->'subscribers')"],
        name: :users_subscribers_index,
        using: :gin,
        concurrently: true
      )
    )
  end
end
