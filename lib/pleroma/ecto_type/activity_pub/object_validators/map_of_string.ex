# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.MapOfString do
  use Ecto.Type

  alias Pleroma.MultiLanguage

  def type, do: :map

  def cast(object) do
    with {status, %{} = data} when status in [:modified, :ok] <- MultiLanguage.validate_map(object) do
      {:ok, data}
    else
      {:modified, nil} -> {:ok, nil}

      {:error, _} -> :error
    end
  end

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
