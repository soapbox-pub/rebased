# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.AuthenticationPlug do
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User

  import Plug.Conn

  require Logger

  def init(options), do: options

  def checkpw(password, "$6" <> _ = password_hash) do
    :crypt.crypt(password, password_hash) == password_hash
  end

  def checkpw(password, "$2" <> _ = password_hash) do
    # Handle bcrypt passwords for Mastodon migration
    Bcrypt.verify_pass(password, password_hash)
  end

  def checkpw(password, "$pbkdf2" <> _ = password_hash) do
    Pbkdf2.verify_pass(password, password_hash)
  end

  def checkpw(_password, _password_hash) do
    Logger.error("Password hash not recognized")
    false
  end

  def maybe_update_password(%User{password_hash: "$2" <> _} = user, password) do
    do_update_password(user, password)
  end

  def maybe_update_password(%User{password_hash: "$6" <> _} = user, password) do
    do_update_password(user, password)
  end

  def maybe_update_password(user, _), do: {:ok, user}

  defp do_update_password(user, password) do
    user
    |> User.password_update_changeset(%{
      "password" => password,
      "password_confirmation" => password
    })
    |> Pleroma.Repo.update()
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
    if checkpw(password, password_hash) do
      {:ok, auth_user} = maybe_update_password(auth_user, password)

      conn
      |> assign(:user, auth_user)
      |> OAuthScopesPlug.skip_plug()
    else
      conn
    end
  end

  def call(%{assigns: %{auth_credentials: %{password: _}}} = conn, _) do
    Pbkdf2.no_user_verify()
    conn
  end

  def call(conn, _), do: conn
end
