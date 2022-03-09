# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddTrustedToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add(:trusted, :boolean, default: false)
    end
  end
end
