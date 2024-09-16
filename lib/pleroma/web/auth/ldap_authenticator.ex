# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.LDAPAuthenticator do
  alias Pleroma.User

  require Logger

  import Pleroma.Web.Auth.Helpers, only: [fetch_credentials: 1, fetch_user: 1]

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
    tls = Keyword.get(ldap, :tls, false)
    cacertfile = Keyword.get(ldap, :cacertfile) || CAStore.file_path()

    default_secure_opts = [
      verify: :verify_peer,
      cacerts: decode_certfile(cacertfile),
      customize_hostname_check: [
        fqdn_fun: fn _ -> to_charlist(host) end
      ]
    ]

    sslopts = Keyword.merge(default_secure_opts, Keyword.get(ldap, :sslopts, []))
    tlsopts = Keyword.merge(default_secure_opts, Keyword.get(ldap, :tlsopts, []))

    # :sslopts can only be included in :eldap.open/2 when {ssl: true}
    # or the connection will fail
    options =
      if ssl do
        [{:port, port}, {:ssl, ssl}, {:sslopts, sslopts}, {:timeout, @connection_timeout}]
      else
        [{:port, port}, {:ssl, ssl}, {:timeout, @connection_timeout}]
      end

    case :eldap.open([to_charlist(host)], options) do
      {:ok, connection} ->
        try do
          cond do
            ssl ->
              :application.ensure_all_started(:ssl)

            tls ->
              case :eldap.start_tls(
                     connection,
                     tlsopts,
                     @connection_timeout
                   ) do
                :ok ->
                  :ok

                error ->
                  Logger.error("Could not start TLS: #{inspect(error)}")
                  :eldap.close(connection)
              end

            true ->
              :ok
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
            register_user(connection, base, uid, name)
        end

      error ->
        Logger.error("Could not bind LDAP user #{name}: #{inspect(error)}")
        {:error, {:ldap_bind_error, error}}
    end
  end

  defp register_user(connection, base, uid, name) do
    case :eldap.search(connection, [
           {:base, to_charlist(base)},
           {:filter, :eldap.equalityMatch(to_charlist(uid), to_charlist(name))},
           {:scope, :eldap.wholeSubtree()},
           {:timeout, @search_timeout}
         ]) do
      # The :eldap_search_result record structure changed in OTP 24.3 and added a controls field
      # https://github.com/erlang/otp/pull/5538
      {:ok, {:eldap_search_result, [{:eldap_entry, _object, attributes}], _referrals}} ->
        try_register(name, attributes)

      {:ok, {:eldap_search_result, [{:eldap_entry, _object, attributes}], _referrals, _controls}} ->
        try_register(name, attributes)

      error ->
        Logger.error("Couldn't register user because LDAP search failed: #{inspect(error)}")
        {:error, {:ldap_search_error, error}}
    end
  end

  defp try_register(name, attributes) do
    params = %{
      name: name,
      nickname: name,
      password: nil
    }

    params =
      case List.keyfind(attributes, ~c"mail", 0) do
        {_, [mail]} -> Map.put_new(params, :email, :erlang.list_to_binary(mail))
        _ -> params
      end

    changeset = User.register_changeset_ldap(%User{}, params)

    case User.register(changeset) do
      {:ok, user} -> user
      error -> error
    end
  end

  defp decode_certfile(file) do
    with {:ok, data} <- File.read(file) do
      data
      |> :public_key.pem_decode()
      |> Enum.map(fn {_, b, _} -> b end)
    else
      _ ->
        Logger.error("Unable to read certfile: #{file}")
        []
    end
  end
end
