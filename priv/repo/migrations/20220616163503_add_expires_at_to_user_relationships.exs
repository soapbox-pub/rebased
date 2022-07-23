# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddExpiresAtToUserRelationships do
  use Ecto.Migration

  def change do
    alter table(:user_relationships) do
      add_if_not_exists(:expires_at, :utc_datetime)
    end
  end
end
