# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:webhooks) do
      add(:url, :string, null: false)
      add(:events, {:array, :string}, null: false, default: [])
      add(:secret, :string, null: false, default: "")
      add(:enabled, :boolean, null: false, default: true)

      timestamps()
    end

    create_if_not_exists(unique_index(:webhooks, [:url]))
  end
end
