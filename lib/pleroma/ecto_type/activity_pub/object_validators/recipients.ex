# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.Recipients do
  use Ecto.Type

  alias Pleroma.EctoType.ActivityPub.ObjectValidators.ObjectID

  def type, do: {:array, ObjectID}

  def cast(object) when is_binary(object) do
    cast([object])
  end

  def cast(data) when is_list(data) do
    data
    |> Enum.reduce_while({:ok, []}, fn
      nil, {:ok, list} ->
        {:cont, {:ok, list}}

      element, {:ok, list} ->
        case ObjectID.cast(element) do
          {:ok, id} ->
            {:cont, {:ok, [id | list]}}

          _ ->
            {:halt, {:error, element}}
        end
    end)
  end

  def cast(data) do
    {:error, data}
  end

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
