# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.SimplePolicyStringToTuple do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  def up, do: ConfigDB.get_by_params(%{group: :pleroma, key: :mrf_simple}) |> update_to_tuples
  def down, do: ConfigDB.get_by_params(%{group: :pleroma, key: :mrf_simple}) |> update_to_strings

  defp update_to_tuples(%{value: value}) do
    new_value =
      value
      |> Enum.map(fn {k, v} ->
        {k,
         Enum.map(v, fn
           {instance, reason} -> {instance, reason}
           instance -> {instance, ""}
         end)}
      end)

    ConfigDB.update_or_create(%{group: :pleroma, key: :mrf_simple, value: new_value})
  end

  defp update_to_tuples(nil), do: {:ok, nil}

  defp update_to_strings(%{value: value}) do
    new_value =
      value
      |> Enum.map(fn {k, v} ->
        {k,
         Enum.map(v, fn
           {instance, _} -> instance
           instance -> instance
         end)}
      end)

    ConfigDB.update_or_create(%{group: :pleroma, key: :mrf_simple, value: new_value})
  end

  defp update_to_strings(nil), do: {:ok, nil}
end
