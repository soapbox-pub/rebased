# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.DataMigrationFailedId do
  use Ecto.Schema
  alias Pleroma.DataMigration

  schema "data_migration_failed_ids" do
    belongs_to(:data_migration, DataMigration)
    field(:record_id, FlakeId.Ecto.CompatType)
  end
end
