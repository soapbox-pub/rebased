# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Maps do
  def put_if_present(map, key, value, value_function \\ &{:ok, &1}) when is_map(map) do
    with false <- is_nil(key),
         false <- is_nil(value),
         {:ok, new_value} <- value_function.(value) do
      Map.put(map, key, new_value)
    else
      _ -> map
    end
  end

  def safe_put_in(data, keys, value) when is_map(data) and is_list(keys) do
    Kernel.put_in(data, keys, value)
  rescue
    _ -> data
  end

  def filter_empty_values(data) do
    data
    |> Map.filter(fn
      {_k, nil} -> false
      {_k, ""} -> false
      {_k, []} -> false
      {_k, %{} = v} -> Map.keys(v) != []
      {_k, _v} -> true
    end)
  end
end
