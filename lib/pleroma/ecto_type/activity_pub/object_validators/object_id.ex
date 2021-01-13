# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.ObjectID do
  use Ecto.Type

  def type, do: :string

  def cast(object) when is_binary(object) do
    # Host has to be present and scheme has to be an http scheme (for now)
    case URI.parse(object) do
      %URI{host: nil} -> :error
      %URI{host: ""} -> :error
      %URI{scheme: scheme} when scheme in ["https", "http"] -> {:ok, object}
      _ -> :error
    end
  end

  def cast(%{"id" => object}), do: cast(object)

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
