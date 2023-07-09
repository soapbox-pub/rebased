# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.AdminSecretAuthenticationPlug do
  import Plug.Conn

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.User
  alias Pleroma.Web.Plugs.RateLimiter

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(conn, _) do
    if secret_token() do
      authenticate(conn)
    else
      conn
    end
  end

  defp authenticate(%{params: %{"admin_token" => admin_token}} = conn) do
    if admin_token == secret_token() do
      assign_admin_user(conn)
    else
      handle_bad_token(conn)
    end
  end

  defp authenticate(conn) do
    token = secret_token()

    case get_req_header(conn, "x-admin-token") do
      blank when blank in [[], [""]] -> conn
      [^token] -> assign_admin_user(conn)
      _ -> handle_bad_token(conn)
    end
  end

  defp secret_token do
    case Pleroma.Config.get(:admin_token) do
      blank when blank in [nil, ""] -> nil
      token -> token
    end
  end

  defp assign_admin_user(conn) do
    conn
    |> assign(:user, %User{is_admin: true})
    |> AuthHelper.skip_oauth()
  end

  defp handle_bad_token(conn) do
    RateLimiter.call(conn, name: :authentication)
  end
end
