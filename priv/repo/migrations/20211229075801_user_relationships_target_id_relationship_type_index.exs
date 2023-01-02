# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UserRelationshipsTargetIdRelationshipTypeIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:user_relationships, [:target_id, :relationship_type]))
  end
end
