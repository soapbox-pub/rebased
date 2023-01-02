# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeleteHashtagsObjectsCascade do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE hashtags_objects DROP CONSTRAINT hashtags_objects_object_id_fkey")

    alter table(:hashtags_objects) do
      modify(:object_id, references(:objects, on_delete: :delete_all))
    end
  end

  def down do
    execute("ALTER TABLE hashtags_objects DROP CONSTRAINT hashtags_objects_object_id_fkey")

    alter table(:hashtags_objects) do
      modify(:object_id, references(:objects, on_delete: :nothing))
    end
  end
end
