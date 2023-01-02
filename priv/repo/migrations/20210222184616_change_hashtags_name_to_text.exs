# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChangeHashtagsNameToText do
  use Ecto.Migration

  def up do
    alter table(:hashtags) do
      modify(:name, :text)
    end
  end

  def down do
    alter table(:hashtags) do
      modify(:name, :citext)
    end
  end
end
