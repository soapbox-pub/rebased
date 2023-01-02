# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFollowingAddressToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:following_address, :string, unique: true)
    end
  end
end
