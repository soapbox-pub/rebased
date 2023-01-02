# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MakeFollowingPostgresArray do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:following_temp, {:array, :string})
    end

    execute("""
    update users set following_temp = array(select jsonb_array_elements_text(following));
    """)

    alter table(:users) do
      remove(:following)
    end

    rename(table(:users), :following_temp, to: :following)
  end

  def down, do: :ok
end
