# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.LoggerMetadataPath do
  def init(opts), do: opts

  def call(conn, _) do
    Logger.metadata(path: conn.request_path)
    conn
  end
end
