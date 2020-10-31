# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureUserKeyPlug do
  import Plug.Conn

  @moduledoc "Ensures `conn.assigns.user` is initialized."

  def init(opts) do
    opts
  end

  def call(%{assigns: %{user: _}} = conn, _), do: conn

  def call(conn, _) do
    assign(conn, :user, nil)
  end
end
