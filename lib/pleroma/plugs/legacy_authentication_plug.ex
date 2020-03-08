# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.LegacyAuthenticationPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(
        %{
          assigns: %{
            auth_user: %{password_hash: "$6$" <> _ = password_hash} = auth_user,
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    with ^password_hash <- :crypt.crypt(password, password_hash),
         {:ok, user} <-
           User.reset_password(auth_user, %{password: password, password_confirmation: password}) do
      conn
      |> assign(:auth_user, user)
      |> assign(:user, user)
    else
      _ ->
        conn
    end
  end

  def call(conn, _) do
    conn
  end
end
