# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RevertCitextChange do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify(:uri, :text)
    end

    # create_if_not_exists(unique_index(:users, :uri))
  end
end
