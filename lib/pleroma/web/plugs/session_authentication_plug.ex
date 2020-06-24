# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.SessionAuthenticationPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    with saved_user_id <- get_session(conn, :user_id),
         %{auth_user: %{id: ^saved_user_id}} <- conn.assigns do
      conn
      |> assign(:user, conn.assigns.auth_user)
    else
      _ -> conn
    end
  end
end
