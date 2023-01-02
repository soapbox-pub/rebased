# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateModerationLog do
  use Ecto.Migration

  def change do
    create table(:moderation_log) do
      add(:data, :map)

      timestamps()
    end
  end
end
