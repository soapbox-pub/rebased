# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameUserSettingsCol do
  use Ecto.Migration

  def up do
    rename(table(:users), :settings, to: :mastofe_settings)
  end

  def down do
    rename(table(:users), :mastofe_settings, to: :settings)
  end
end
