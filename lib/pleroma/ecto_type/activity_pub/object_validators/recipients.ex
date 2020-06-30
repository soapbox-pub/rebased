# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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
    |> Enum.reduce_while({:ok, []}, fn element, {:ok, list} ->
      case ObjectID.cast(element) do
        {:ok, id} ->
          {:cont, {:ok, [id | list]}}

        _ ->
          {:halt, :error}
      end
    end)
  end

  def cast(_) do
    :error
  end

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
