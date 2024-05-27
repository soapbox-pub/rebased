# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.FixMalformedFormatterConfig do
  use Ecto.Migration
  alias Pleroma.ConfigDB

  @config_path %{group: :pleroma, key: Pleroma.Formatter}

  def change do
    with %ConfigDB{value: %{} = opts} <- ConfigDB.get_by_params(@config_path),
         fixed_opts <- Map.to_list(opts) do
      fix_config(fixed_opts)
    else
      _ -> :skipped
    end
  end

  defp fix_config(fixed_opts) when is_list(fixed_opts) do
    {:ok, _} =
      ConfigDB.update_or_create(%{
        group: :pleroma,
        key: Pleroma.Formatter,
        value: fixed_opts
      })

    :ok
  end
end
