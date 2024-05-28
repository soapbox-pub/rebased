# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.BareUri do
  use Ecto.Type

  def type, do: :string

  def cast(uri) when is_binary(uri) do
    parsed = URI.parse(uri)

    if is_nil(parsed.scheme) do
      :error
    else
      {:ok, uri}
    end
  end

  def cast(_), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
