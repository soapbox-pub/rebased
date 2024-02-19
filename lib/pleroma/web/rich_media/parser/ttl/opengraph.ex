# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser.TTL.Opengraph do
  @behaviour Pleroma.Web.RichMedia.Parser.TTL

  @impl true
  def ttl(%{"ttl" => ttl_string}, _url) do
    with ttl <- String.to_integer(ttl_string) do
      now = DateTime.utc_now() |> DateTime.to_unix()
      now + ttl
    else
      _ -> nil
    end
  end

  def ttl(_, _), do: nil
end
