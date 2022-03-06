# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChangePushSubscriptionsVarchar do
  use Ecto.Migration

  def up do
    alter table(:push_subscriptions) do
      modify(:endpoint, :varchar)
    end
  end

  def down do
    alter table(:push_subscriptions) do
      modify(:endpoint, :string)
    end
  end
end
