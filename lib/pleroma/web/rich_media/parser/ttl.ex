# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.TTL do
  @callback ttl(map(), String.t()) :: integer() | nil

  def get_from_image(data, url) do
    [:rich_media, :ttl_setters]
    |> Pleroma.Config.get()
    |> Enum.reduce({:ok, nil}, fn
      module, {:ok, _ttl} ->
        module.ttl(data, url)

      _, error ->
        error
    end)
  end
end
