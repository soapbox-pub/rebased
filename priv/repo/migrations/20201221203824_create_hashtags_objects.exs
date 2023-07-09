# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateHashtagsObjects do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:hashtags_objects, primary_key: false) do
      add(:hashtag_id, references(:hashtags), null: false, primary_key: true)
      add(:object_id, references(:objects), null: false, primary_key: true)
    end

    # Note: PK index: "hashtags_objects_pkey" PRIMARY KEY, btree (hashtag_id, object_id)
    create_if_not_exists(index(:hashtags_objects, [:object_id]))
  end
end
