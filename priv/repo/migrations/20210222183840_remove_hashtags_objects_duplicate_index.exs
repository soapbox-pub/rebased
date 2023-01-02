# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveHashtagsObjectsDuplicateIndex do
  use Ecto.Migration

  @moduledoc "Removes `hashtags_objects_hashtag_id_object_id_index` index (duplicate of PK index)."

  def up do
    drop_if_exists(unique_index(:hashtags_objects, [:hashtag_id, :object_id]))
  end

  def down, do: nil
end
