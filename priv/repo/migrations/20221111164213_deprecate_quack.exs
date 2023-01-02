# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeprecateQuack do
  use Ecto.Migration
  alias Pleroma.ConfigDB

  def up do
    :quack
    |> ConfigDB.get_all_by_group()
    |> Enum.each(&ConfigDB.delete/1)

    logger_config = ConfigDB.get_by_group_and_key(:logger, :backends)

    if not is_nil(logger_config) do
      %{value: backends} = logger_config
      new_backends = backends -- [Quack.Logger]
      {:ok, _} = ConfigDB.update_or_create(%{group: :logger, key: :backends, value: new_backends})
    end
  end

  def down, do: :ok
end
