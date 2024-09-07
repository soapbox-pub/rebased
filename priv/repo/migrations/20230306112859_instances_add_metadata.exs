# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.InstancesAddMetadata do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add_if_not_exists(:metadata, :map)
      add_if_not_exists(:metadata_updated_at, :utc_datetime)
    end
  end
end
