# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddMastodonApps do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:apps) do
      add(:client_name, :string)
      add(:redirect_uris, :string)
      add(:scopes, :string)
      add(:website, :string)
      add(:client_id, :string)
      add(:client_secret, :string)

      timestamps()
    end
  end
end
