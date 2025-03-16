# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddHintToRules do
  use Ecto.Migration

  def change do
    alter table(:rules) do
      add_if_not_exists(:hint, :text)
    end
  end
end
