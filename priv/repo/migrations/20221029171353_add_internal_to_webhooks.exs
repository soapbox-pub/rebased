# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddInternalToWebhooks do
  use Ecto.Migration

  def change do
    alter table(:webhooks) do
      add(:internal, :boolean, default: false, null: false)
    end
  end
end
