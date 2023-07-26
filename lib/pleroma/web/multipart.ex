# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# <https://hexdocs.pm/plug/Plug.Parsers.MULTIPART.html#module-dynamic-configuration>
defmodule Pleroma.Web.Multipart do
  @multipart Plug.Parsers.MULTIPART

  def init(opts) do
    opts
  end

  def parse(conn, "multipart", subtype, headers, opts) do
    length = Pleroma.Config.get([:instance, :upload_limit])
    opts = @multipart.init([length: length] ++ opts)
    @multipart.parse(conn, "multipart", subtype, headers, opts)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
