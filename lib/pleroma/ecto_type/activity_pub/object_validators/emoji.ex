# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.Emoji do
  use Ecto.Type

  def type, do: :map

  def cast(data) when is_map(data) do
    has_invalid_emoji? =
      Enum.find(data, fn
        {name, uri} when is_binary(name) and is_binary(uri) ->
          # based on ObjectValidators.Uri.cast()
          case URI.parse(uri) do
            %URI{host: nil} -> true
            %URI{host: ""} -> true
            %URI{scheme: scheme} when scheme in ["https", "http"] -> false
            _ -> true
          end

        {_name, _uri} ->
          true
      end)

    if has_invalid_emoji?, do: :error, else: {:ok, data}
  end

  def cast(_data), do: :error

  def dump(data), do: {:ok, data}

  def load(data), do: {:ok, data}
end
