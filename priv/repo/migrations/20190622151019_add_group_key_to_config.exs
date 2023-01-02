# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddGroupKeyToConfig do
  use Ecto.Migration

  def change do
    alter table("config") do
      add(:group, :string)
    end

    drop_if_exists(unique_index("config", :key))
    create_if_not_exists(unique_index("config", [:group, :key]))
  end
end
