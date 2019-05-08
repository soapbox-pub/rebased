# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.LDAPAuthenticator do
  alias Pleroma.User

  require Logger

  import Pleroma.Web.Auth.Authenticator,
    only: [fetch_credentials: 1, fetch_user: 1]

  @behaviour Pleroma.Web.Auth.Authenticator
  @base Pleroma.Web.Auth.PleromaAuthenticator

  @connection_timeout 10_000
  @search_timeout 10_000

  defdelegate get_registration(conn), to: @base
  defdelegate create_from_registration(conn, registration), to: @base
  defdelegate handle_error(conn, error), to: @base
  defdelegate auth_template, to: @base
  defdelegate oauth_consumer_template, to: @base

  def get_user(%Plug.Conn{} = conn) do
    with {:ldap, true} <- {:ldap, Pleroma.Config.get([:ldap, :enabled])},
         {:ok, {name, password}} <- fetch_credentials(conn),
         %User{} = user <- ldap_user(name, password) do
      {:ok, user}
    else
      {:error, {:ldap_connection_error, _}} ->
        # When LDAP is unavailable, try default authenticator
        @base.get_user(conn)

      {:ldap, _} ->
        @base.get_user(conn)

      error ->
        error
    end
  end

  defp ldap_user(name, password) do
    ldap = Pleroma.Config.get(:ldap, [])
    host = Keyword.get(ldap, :host, "localhost")
    port = Keyword.get(ldap, :port, 389)
    ssl = Keyword.get(ldap, :ssl, false)
    sslopts = Keyword.get(ldap, :sslopts, [])

    options =
      [{:port, port}, {:ssl, ssl}, {:timeout, @connection_timeout}] ++
        if sslopts != [], do: [{:sslopts, sslopts}], else: []

    case :eldap.open([to_charlist(host)], options) do
      {:ok, connection} ->
        try do
          if Keyword.get(ldap, :tls, false) do
            :application.ensure_all_started(:ssl)

            case :eldap.start_tls(
                   connection,
                   Keyword.get(ldap, :tlsopts, []),
                   @connection_timeout
                 ) do
              :ok ->
                :ok

              error ->
                Logger.error("Could not start TLS: #{inspect(error)}")
            end
          end

          bind_user(connection, ldap, name, password)
        after
          :eldap.close(connection)
        end

      {:error, error} ->
        Logger.error("Could not open LDAP connection: #{inspect(error)}")
        {:error, {:ldap_connection_error, error}}
    end
  end

  defp bind_user(connection, ldap, name, password) do
    uid = Keyword.get(ldap, :uid, "cn")
    base = Keyword.get(ldap, :base)

    case :eldap.simple_bind(connection, "#{uid}=#{name},#{base}", password) do
      :ok ->
        case fetch_user(name) do
          %User{} = user ->
            user

          _ ->
            register_user(connection, base, uid, name, password)
        end

      error ->
        error
    end
  end

  defp register_user(connection, base, uid, name, password) do
    case :eldap.search(connection, [
           {:base, to_charlist(base)},
           {:filter, :eldap.equalityMatch(to_charlist(uid), to_charlist(name))},
           {:scope, :eldap.wholeSubtree()},
           {:attributes, ['mail', 'email']},
           {:timeout, @search_timeout}
         ]) do
      {:ok, {:eldap_search_result, [{:eldap_entry, _, attributes}], _}} ->
        with {_, [mail]} <- List.keyfind(attributes, 'mail', 0) do
          params = %{
            email: :erlang.list_to_binary(mail),
            name: name,
            nickname: name,
            password: password,
            password_confirmation: password
          }

          changeset = User.register_changeset(%User{}, params)

          case User.register(changeset) do
            {:ok, user} -> user
            error -> error
          end
        else
          _ ->
            Logger.error("Could not find LDAP attribute mail: #{inspect(attributes)}")
            {:error, :ldap_registration_missing_attributes}
        end

      error ->
        error
    end
  end
end
