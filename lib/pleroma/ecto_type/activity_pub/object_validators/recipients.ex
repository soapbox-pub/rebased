# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.Recipients do
  use Ecto.Type

  alias Pleroma.EctoType.ActivityPub.ObjectValidators.ObjectID

  def type, do: {:array, ObjectID}

  def cast(object) when is_binary(object) do
    cast([object])
  end

  def cast(object) when is_map(object) do
    case ObjectID.cast(object) do
      {:ok, data} -> {:ok, [data]}
      _ -> :error
    end
  end

  def cast(data) when is_list(data) do
    data =
      data
      |> Enum.reduce_while([], fn element, list ->
        case ObjectID.cast(element) do
          {:ok, id} ->
            {:cont, [id | list]}

          _ ->
            {:cont, list}
        end
      end)
      |> Enum.sort()
      |> Enum.uniq()

    {:ok, data}
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
