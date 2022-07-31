# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddMultiFactorAuthenticationSettingsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:multi_factor_authentication_settings, :map, default: %{})
    end
  end
end
