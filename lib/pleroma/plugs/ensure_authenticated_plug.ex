# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.EnsureAuthenticatedPlug do
  import Plug.Conn
  import Pleroma.Web.TranslationHelpers

  alias Pleroma.User

  use Pleroma.Web, :plug

  def init(options) do
    options
  end

  @impl true
  def perform(%{assigns: %{user: %User{}}} = conn, _) do
    conn
  end

  def perform(conn, _) do
    conn
    |> render_error(:forbidden, "Invalid credentials.")
    |> halt()
  end
end
