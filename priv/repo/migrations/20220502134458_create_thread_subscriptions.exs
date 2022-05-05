# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateThreadSubscriptions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:thread_subscriptions) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:context, :string, null: false)
    end

    create_if_not_exists(unique_index(:thread_subscriptions, [:user_id, :context]))
  end
end
