# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateWebsubServerSubscription do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:websub_server_subscriptions) do
      add(:topic, :string)
      add(:callback, :string)
      add(:secret, :string)
      add(:valid_until, :naive_datetime)
      add(:state, :string)

      timestamps()
    end
  end
end
