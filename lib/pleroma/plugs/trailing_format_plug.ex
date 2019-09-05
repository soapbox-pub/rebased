# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.TrailingFormatPlug do
  @moduledoc "Calls TrailingFormatPlug for specific paths. Ideally we would just do this in the router, but TrailingFormatPlug needs to be called before Plug.Parsers."

  @behaviour Plug
  @paths [
    "/api/statusnet",
    "/api/statuses",
    "/api/qvitter",
    "/api/search",
    "/api/account",
    "/api/friends",
    "/api/mutes",
    "/api/media",
    "/api/favorites",
    "/api/blocks",
    "/api/friendships",
    "/api/users",
    "/users",
    "/nodeinfo",
    "/api/help",
    "/api/externalprofile",
    "/notice",
    "/api/pleroma/emoji"
  ]

  def init(opts) do
    TrailingFormatPlug.init(opts)
  end

  for path <- @paths do
    def call(%{request_path: unquote(path) <> _} = conn, opts) do
      TrailingFormatPlug.call(conn, opts)
    end
  end

  def call(conn, _opts), do: conn
end
