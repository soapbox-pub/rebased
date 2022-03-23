# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameTimeoutInPools do
  use Ecto.Migration

  def change do
    with %Pleroma.ConfigDB{} = config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: :pools}) do
      updated_value =
        Enum.map(config.value, fn {pool, pool_value} ->
          with {timeout, value} when is_integer(timeout) <- Keyword.pop(pool_value, :timeout) do
            {pool, Keyword.put(value, :recv_timeout, timeout)}
          end
        end)

      config
      |> Ecto.Changeset.change(value: updated_value)
      |> Pleroma.Repo.update()
    end
  end
end
