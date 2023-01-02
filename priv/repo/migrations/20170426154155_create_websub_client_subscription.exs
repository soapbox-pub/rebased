# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateWebsubClientSubscription do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:websub_client_subscriptions) do
      add(:topic, :string)
      add(:secret, :string)
      add(:valid_until, :naive_datetime_usec)
      add(:state, :string)
      add(:subscribers, :map)

      timestamps()
    end
  end
end
