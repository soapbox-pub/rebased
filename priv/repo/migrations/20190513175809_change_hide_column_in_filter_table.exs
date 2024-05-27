# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ChangeHideColumnInFilterTable do
  use Ecto.Migration

  def up do
    alter table(:filters) do
      modify(:hide, :boolean, default: false)
    end
  end

  def down do
    alter table(:filters) do
      modify(:hide, :boolean)
    end
  end
end
