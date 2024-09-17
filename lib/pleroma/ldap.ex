defmodule Pleroma.LDAP do
  use GenServer

  require Logger

  alias Pleroma.Config
  alias Pleroma.User

  import Pleroma.Web.Auth.Helpers, only: [fetch_user: 1]

  @connection_timeout 10_000
  @search_timeout 10_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(state) do
    case {Config.get(Pleroma.Web.Auth.Authenticator), Config.get([:ldap, :enabled])} do
      {Pleroma.Web.Auth.LDAPAuthenticator, true} ->
        {:ok, state, {:continue, :connect}}

      {Pleroma.Web.Auth.LDAPAuthenticator, false} ->
        Logger.error(
          "LDAP Authenticator enabled but :pleroma, :ldap is not enabled. Auth will not work."
        )

        {:ok, state}

      {_, true} ->
        Logger.warning(
          ":pleroma, :ldap is enabled but Pleroma.Web.Authenticator is not set to the LDAPAuthenticator. LDAP will not be used."
        )

        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_continue(:connect, _state), do: do_handle_connect()

  @impl true
  def handle_info(:connect, _state), do: do_handle_connect()

  def handle_info({:bind_after_reconnect, name, password, from}, state) do
    result = bind_user(state[:connection], name, password)

    GenServer.reply(from, result)

    {:noreply, state}
  end

  defp do_handle_connect do
    state =
      case connect() do
        {:ok, connection} ->
          :eldap.controlling_process(connection, self())
          Process.link(connection)
          [connection: connection]

        _ ->
          Logger.error("Failed to connect to LDAP. Retrying in 5000ms")
          Process.send_after(self(), :connect, 5_000)
          []
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:bind_user, name, password}, from, state) do
    case bind_user(state[:connection], name, password) do
      :needs_reconnect ->
        Process.send(self(), {:bind_after_reconnect, name, password, from}, [])
        {:noreply, state, {:continue, :connect}}

      result ->
        {:reply, result, state, :hibernate}
    end
  end

  @impl true
  def terminate(_, state) do
    connection = Keyword.get(state, :connection)

    if not is_nil(connection) do
      :eldap.close(connection)
    end

    :ok
  end

  defp connect do
    ldap = Config.get(:ldap, [])
    host = Keyword.get(ldap, :host, "localhost")
    port = Keyword.get(ldap, :port, 389)
    ssl = Keyword.get(ldap, :ssl, false)
    tls = Keyword.get(ldap, :tls, false)
    cacertfile = Keyword.get(ldap, :cacertfile) || CAStore.file_path()

    if ssl, do: Application.ensure_all_started(:ssl)

    default_secure_opts = [
      verify: :verify_peer,
      cacerts: decode_certfile(cacertfile),
      customize_hostname_check: [
        fqdn_fun: fn _ -> to_charlist(host) end
      ]
    ]

    sslopts = Keyword.merge(default_secure_opts, Keyword.get(ldap, :sslopts, []))
    tlsopts = Keyword.merge(default_secure_opts, Keyword.get(ldap, :tlsopts, []))

    default_options = [{:port, port}, {:ssl, ssl}, {:timeout, @connection_timeout}]

    # :sslopts can only be included in :eldap.open/2 when {ssl: true}
    # or the connection will fail
    options =
      if ssl do
        default_options ++ [{:sslopts, sslopts}]
      else
        default_options
      end

    case :eldap.open([to_charlist(host)], options) do
      {:ok, connection} ->
        try do
          cond do
            tls ->
              case :eldap.start_tls(
                     connection,
                     tlsopts,
                     @connection_timeout
                   ) do
                :ok ->
                  {:ok, connection}

                error ->
                  Logger.error("Could not start TLS: #{inspect(error)}")
                  :eldap.close(connection)
              end

            true ->
              {:ok, connection}
          end
        after
          :ok
        end

      {:error, error} ->
        Logger.error("Could not open LDAP connection: #{inspect(error)}")
        {:error, {:ldap_connection_error, error}}
    end
  end

  defp bind_user(connection, name, password) do
    uid = Config.get([:ldap, :uid], "cn")
    base = Config.get([:ldap, :base])

    case :eldap.simple_bind(connection, "#{uid}=#{name},#{base}", password) do
      :ok ->
        case fetch_user(name) do
          %User{} = user ->
            user

          _ ->
            register_user(connection, base, uid, name)
        end

      # eldap does not inform us of socket closure
      # until it is used
      {:error, {:gen_tcp_error, :closed}} ->
        :eldap.close(connection)
        :needs_reconnect

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
