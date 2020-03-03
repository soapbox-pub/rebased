# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.EnsureUserKeyPlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(%{assigns: %{user: _}} = conn, _), do: conn

  def call(conn, _) do
    conn
    |> assign(:user, nil)
  end
end
