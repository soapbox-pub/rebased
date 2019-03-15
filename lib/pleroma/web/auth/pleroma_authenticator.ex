# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticator do
  alias Comeonin.Pbkdf2
  alias Pleroma.User

  @behaviour Pleroma.Web.Auth.Authenticator

  def get_user(%Plug.Conn{} = conn) do
    {name, password} =
      case conn.params do
        %{"authorization" => %{"name" => name, "password" => password}} ->
          {name, password}

        %{"grant_type" => "password", "username" => name, "password" => password} ->
          {name, password}
      end

    with {_, %User{} = user} <- {:user, User.get_by_nickname_or_email(name)},
         {_, true} <- {:checkpw, Pbkdf2.checkpw(password, user.password_hash)} do
      {:ok, user}
    else
      error ->
        {:error, error}
    end
  end

  def handle_error(%Plug.Conn{} = _conn, error) do
    error
  end

  def auth_template, do: nil
end
