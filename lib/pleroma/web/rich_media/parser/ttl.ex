# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.TTL do
  @callback ttl(map(), String.t()) :: integer() | nil

  @spec process(map(), String.t()) :: {:ok, integer() | nil}
  def process(data, url) do
    [:rich_media, :ttl_setters]
    |> Pleroma.Config.get()
    |> Enum.reduce_while({:ok, nil}, fn
      module, acc ->
        case module.ttl(data, url) do
          ttl when is_number(ttl) -> {:halt, {:ok, ttl}}
          _ -> {:cont, acc}
        end
    end)
  end
end
