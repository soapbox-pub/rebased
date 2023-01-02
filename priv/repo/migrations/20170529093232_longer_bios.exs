# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.LongerBios do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify(:bio, :text)
    end
  end

  def down do
    alter table(:users) do
      modify(:bio, :string)
    end
  end
end
