# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.AdminSecretAuthenticationPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def secret_token do
    Pleroma.Config.get(:admin_token)
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(conn, _) do
    if secret_token() do
      authenticate(conn)
    else
      conn
    end
  end

  def authenticate(%{params: %{"admin_token" => admin_token}} = conn) do
    if admin_token == secret_token() do
      assign(conn, :user, %User{is_admin: true})
    else
      conn
    end
  end

  def authenticate(conn) do
    token = secret_token()

    case get_req_header(conn, "x-admin-token") do
      [^token] -> assign(conn, :user, %User{is_admin: true})
      _ -> conn
    end
  end
end
