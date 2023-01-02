# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFollowerAddressIndexToUsers do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(index(:users, [:follower_address], concurrently: true))
    create(index(:users, [:following], concurrently: true, using: :gin))
  end
end
