# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.LDAPAuthenticator do
  alias Pleroma.LDAP
  alias Pleroma.User

  import Pleroma.Web.Auth.Helpers, only: [fetch_credentials: 1]

  @behaviour Pleroma.Web.Auth.Authenticator
  @base Pleroma.Web.Auth.PleromaAuthenticator

  defdelegate get_registration(conn), to: @base
  defdelegate create_from_registration(conn, registration), to: @base
  defdelegate handle_error(conn, error), to: @base
  defdelegate auth_template, to: @base
  defdelegate oauth_consumer_template, to: @base

  def get_user(%Plug.Conn{} = conn) do
    with {:ldap, true} <- {:ldap, Pleroma.Config.get([:ldap, :enabled])},
         {:ok, {name, password}} <- fetch_credentials(conn),
         %User{} = user <- LDAP.bind_user(name, password) do
      {:ok, user}
    else
      {:ldap, _} ->
        @base.get_user(conn)

      error ->
        error
    end
  end

  def change_password(user, password, new_password, new_password) do
    case LDAP.change_password(user.nickname, password, new_password) do
      :ok -> {:ok, user}
      e -> e
    end
  end

  def change_password(_, _, _, _), do: {:error, :password_confirmation}
end
