# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserIsAdminPlug do
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{is_admin: true}}} = conn, _) do
    conn
  end

  def call(conn, _) do
    conn
    |> render_error(:forbidden, "User is not admin.")
    |> halt
  end
end
