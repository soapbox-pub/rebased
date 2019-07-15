# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.AuthenticationPlug do
  alias Comeonin.Pbkdf2
  import Plug.Conn
  alias Pleroma.User
  require Logger

  def init(options) do
    options
  end

  def checkpw(password, password_hash) do
    cond do
      String.starts_with?(password_hash, "$pbkdf2") ->
        Pbkdf2.checkpw(password, password_hash)

      String.starts_with?(password_hash, "$6") ->
        :crypt.crypt(password, password_hash) == password_hash

      true ->
        Logger.error("Password hash not recognized")
        false
    end
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(
        %{
          assigns: %{
            auth_user: %{password_hash: password_hash} = auth_user,
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    if Pbkdf2.checkpw(password, password_hash) do
      conn
      |> assign(:user, auth_user)
    else
      conn
    end
  end

  def call(%{assigns: %{auth_credentials: %{password: _}}} = conn, _) do
    Pbkdf2.dummy_checkpw()
    conn
  end

  def call(conn, _), do: conn
end
