# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddMoveSupportToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:also_known_as, {:array, :string}, default: [], null: false)
      add(:allow_following_move, :boolean, default: true, null: false)
    end
  end
end
