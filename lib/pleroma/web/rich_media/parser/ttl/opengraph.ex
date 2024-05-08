# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.TTL.Opengraph do
  @behaviour Pleroma.Web.RichMedia.Parser.TTL

  @impl true
  def ttl(%{"ttl" => ttl_string}, _url) when is_binary(ttl_string) do
    try do
      ttl = String.to_integer(ttl_string)
      now = DateTime.utc_now() |> DateTime.to_unix()
      now + ttl
    rescue
      _ -> nil
    end
  end

  def ttl(_, _), do: nil
end
