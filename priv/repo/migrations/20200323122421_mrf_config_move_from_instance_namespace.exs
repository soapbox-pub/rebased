# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MrfConfigMoveFromInstanceNamespace do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  @old_keys [:rewrite_policy, :mrf_transparency, :mrf_transparency_exclusions]
  def change do
    config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})

    if config do
      mrf =
        config.value
        |> Keyword.take(@old_keys)
        |> Keyword.new(fn
          {:rewrite_policy, policies} -> {:policies, policies}
          {:mrf_transparency, transparency} -> {:transparency, transparency}
          {:mrf_transparency_exclusions, exclusions} -> {:transparency_exclusions, exclusions}
        end)

      if mrf != [] do
        {:ok, _} =
          %ConfigDB{}
          |> ConfigDB.changeset(%{group: :pleroma, key: :mrf, value: mrf})
          |> Pleroma.Repo.insert()

        new_instance = Keyword.drop(config.value, @old_keys)

        if new_instance != [] do
          {:ok, _} =
            config
            |> ConfigDB.changeset(%{value: new_instance})
            |> Pleroma.Repo.update()
        else
          {:ok, _} = ConfigDB.delete(config)
        end
      end
    end
  end
end
