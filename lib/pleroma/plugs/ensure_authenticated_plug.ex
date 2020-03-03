# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.EnsureAuthenticatedPlug do
  import Plug.Conn
  import Pleroma.Web.TranslationHelpers
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _) do
    conn
  end

  def call(conn, _) do
    conn
    |> render_error(:forbidden, "Invalid credentials.")
    |> halt
  end
end
