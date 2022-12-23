# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.InstancesAddFavicon do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add(:favicon, :string)
      add(:favicon_updated_at, :naive_datetime)
    end
  end
end
