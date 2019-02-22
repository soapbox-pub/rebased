# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.LDAP do
  alias Pleroma.User

  require Logger

  @connection_timeout 10_000
  @search_timeout 10_000

  def get_user(name, password) do
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
          uid = Keyword.get(ldap, :uid, "cn")
          base = Keyword.get(ldap, :base)

          case :eldap.simple_bind(connection, "#{uid}=#{name},#{base}", password) do
            :ok ->
              case User.get_by_nickname_or_email(name) do
                %User{} = user ->
                  user

                _ ->
                  register_user(connection, base, uid, name, password)
              end

            error ->
              error
          end
        after
          :eldap.close(connection)
        end

      {:error, error} ->
        Logger.error("Could not open LDAP connection: #{inspect(error)}")
        {:error, {:ldap_connection_error, error}}
    end
  end

  def register_user(connection, base, uid, name, password) do
    case :eldap.search(connection, [
           {:base, to_charlist(base)},
           {:filter, :eldap.equalityMatch(to_charlist(uid), to_charlist(name))},
           {:scope, :eldap.wholeSubtree()},
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
          _ -> {:error, :ldap_registration_missing_attributes}
        end

      error ->
        error
    end
  end
end
