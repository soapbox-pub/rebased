# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFollowerAddressToUser do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:follower_address, :string, unique: true)
    end
  end

  def down do
    alter table(:users) do
      remove(:follower_address)
    end
  end
end
