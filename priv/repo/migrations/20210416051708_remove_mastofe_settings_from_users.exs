# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveMastofeSettingsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove_if_exists(:mastofe_settings, :map)
    end
  end
end
