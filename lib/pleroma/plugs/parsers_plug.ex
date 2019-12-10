# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.Parsers do
  @moduledoc "Initializes Plug.Parsers with upload limit set at boot time"

  @behaviour Plug

  def init(_opts) do
    Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason,
      length: Pleroma.Config.get([:instance, :upload_limit]),
      body_reader: {Pleroma.Web.Plugs.DigestPlug, :read_body, []}
    )
  end

  defdelegate call(conn, opts), to: Plug.Parsers
end
