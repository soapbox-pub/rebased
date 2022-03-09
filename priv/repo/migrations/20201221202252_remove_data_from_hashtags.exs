# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveDataFromHashtags do
  use Ecto.Migration

  def up do
    alter table(:hashtags) do
      remove_if_exists(:data, :map)
    end
  end

  def down do
    alter table(:hashtags) do
      add_if_not_exists(:data, :map, default: %{})
    end
  end
end
