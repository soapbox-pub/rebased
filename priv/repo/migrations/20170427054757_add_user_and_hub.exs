# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddUserAndHub do
  use Ecto.Migration

  def change do
    alter table(:websub_client_subscriptions) do
      add(:hub, :string)
      add(:user_id, references(:users))
    end
  end
end
