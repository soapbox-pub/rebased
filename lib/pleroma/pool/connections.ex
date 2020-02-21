# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool.Connections do
  use GenServer

  alias Pleroma.Config

  require Logger

  @type domain :: String.t()
  @type conn :: Pleroma.Gun.Conn.t()

  @type t :: %__MODULE__{
          conns: %{domain() => conn()},
          opts: keyword()
        }

  defstruct conns: %{}, opts: []

  alias Pleroma.Gun.API
  alias Pleroma.Gun.Conn

  @spec start_link({atom(), keyword()}) :: {:ok, pid()}
  def start_link({name, opts}) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts), do: {:ok, %__MODULE__{conns: %{}, opts: opts}}

  @spec checkin(String.t() | URI.t(), atom()) :: pid() | nil
  def checkin(url, name)
  def checkin(url, name) when is_binary(url), do: checkin(URI.parse(url), name)

  def checkin(%URI{} = uri, name) do
    timeout = Config.get([:connections_pool, :receive_connection_timeout], 250)

    GenServer.call(
      name,
      {:checkin, uri},
      timeout
    )
  end

  @spec open_conn(String.t() | URI.t(), atom(), keyword()) :: :ok
  def open_conn(url, name, opts \\ [])
  def open_conn(url, name, opts) when is_binary(url), do: open_conn(URI.parse(url), name, opts)

  def open_conn(%URI{} = uri, name, opts) do
    pool_opts = Config.get([:connections_pool], [])

    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:retry, pool_opts[:retry] || 0)
      |> Map.put_new(:retry_timeout, pool_opts[:retry_timeout] || 100)
      |> Map.put_new(:await_up_timeout, pool_opts[:await_up_timeout] || 5_000)

    GenServer.cast(name, {:open_conn, %{opts: opts, uri: uri}})
  end

  @spec alive?(atom()) :: boolean()
  def alive?(name) do
    pid = Process.whereis(name)
    if pid, do: Process.alive?(pid), else: false
  end

  @spec get_state(atom()) :: t()
  def get_state(name) do
    GenServer.call(name, :state)
  end

  @spec checkout(pid(), pid(), atom()) :: :ok
  def checkout(conn, pid, name) do
    GenServer.cast(name, {:checkout, conn, pid})
  end

  @impl true
  def handle_cast({:open_conn, %{opts: opts, uri: uri}}, state) do
    Logger.debug("opening new #{compose_uri(uri)}")
    max_connections = state.opts[:max_connections]

    key = compose_key(uri)

    if Enum.count(state.conns) < max_connections do
      open_conn(key, uri, state, opts)
    else
      try_to_open_conn(key, uri, state, opts)
    end
  end

  @impl true
  def handle_cast({:checkout, conn_pid, pid}, state) do
    Logger.debug("checkout #{inspect(conn_pid)}")

    state =
      with true <- Process.alive?(conn_pid),
           {key, conn} <- find_conn(state.conns, conn_pid),
           used_by <- List.keydelete(conn.used_by, pid, 0) do
        conn_state =
          if used_by == [] do
            :idle
          else
            conn.conn_state
          end

        put_in(state.conns[key], %{conn | conn_state: conn_state, used_by: used_by})
      else
        false ->
          Logger.debug("checkout for closed conn #{inspect(conn_pid)}")
          state

        nil ->
          Logger.debug("checkout for alive conn #{inspect(conn_pid)}, but is not in state")
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:checkin, uri}, from, state) do
    Logger.debug("checkin #{compose_uri(uri)}")
    key = compose_key(uri)

    case state.conns[key] do
      %{conn: conn, gun_state: gun_state} = current_conn when gun_state == :up ->
        Logger.debug("reusing conn #{compose_uri(uri)}")

        with time <- :os.system_time(:second),
             last_reference <- time - current_conn.last_reference,
             current_crf <- crf(last_reference, 100, current_conn.crf),
             state <-
               put_in(state.conns[key], %{
                 current_conn
                 | last_reference: time,
                   crf: current_crf,
                   conn_state: :active,
                   used_by: [from | current_conn.used_by]
               }) do
          {:reply, conn, state}
        end

      %{gun_state: gun_state} when gun_state == :down ->
        {:reply, nil, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_info({:gun_up, conn_pid, _protocol}, state) do
    state =
      with true <- Process.alive?(conn_pid),
           conn_key when is_binary(conn_key) <- compose_key_gun_info(conn_pid),
           {key, conn} <- find_conn(state.conns, conn_pid, conn_key),
           time <- :os.system_time(:second),
           last_reference <- time - conn.last_reference,
           current_crf <- crf(last_reference, 100, conn.crf) do
        put_in(state.conns[key], %{
          conn
          | gun_state: :up,
            last_reference: time,
            crf: current_crf,
            conn_state: :active,
            retries: 0
        })
      else
        :error_gun_info ->
          Logger.debug(":gun.info caused error")
          state

        false ->
          Logger.debug(":gun_up message for closed conn #{inspect(conn_pid)}")
          state

        nil ->
          Logger.debug(
            ":gun_up message for alive conn #{inspect(conn_pid)}, but deleted from state"
          )

          :ok = API.close(conn_pid)

          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_down, conn_pid, _protocol, _reason, _killed}, state) do
    retries = Config.get([:connections_pool, :retry], 0)
    # we can't get info on this pid, because pid is dead
    state =
      with true <- Process.alive?(conn_pid),
           {key, conn} <- find_conn(state.conns, conn_pid) do
        if conn.retries == retries do
          Logger.debug("closing conn if retries is eq  #{inspect(conn_pid)}")
          :ok = API.close(conn.conn)

          put_in(
            state.conns,
            Map.delete(state.conns, key)
          )
        else
          put_in(state.conns[key], %{
            conn
            | gun_state: :down,
              retries: conn.retries + 1
          })
        end
      else
        false ->
          # gun can send gun_down for closed conn, maybe connection is not closed yet
          Logger.debug(":gun_down message for closed conn #{inspect(conn_pid)}")
          state

        nil ->
          Logger.debug(
            ":gun_down message for alive conn #{inspect(conn_pid)}, but deleted from state"
          )

          :ok = API.close(conn_pid)

          state
      end

    {:noreply, state}
  end

  defp compose_key(%URI{scheme: scheme, host: host, port: port}), do: "#{scheme}:#{host}:#{port}"

  defp compose_key_gun_info(pid) do
    try do
      # sometimes :gun.info can raise MatchError, which lead to pool terminate
      %{origin_host: origin_host, origin_scheme: scheme, origin_port: port} = API.info(pid)

      host =
        case :inet.ntoa(origin_host) do
          {:error, :einval} -> origin_host
          ip -> ip
        end

      "#{scheme}:#{host}:#{port}"
    rescue
      _ -> :error_gun_info
    end
  end

  defp find_conn(conns, conn_pid) do
    Enum.find(conns, fn {_key, conn} ->
      conn.conn == conn_pid
    end)
  end

  defp find_conn(conns, conn_pid, conn_key) do
    Enum.find(conns, fn {key, conn} ->
      key == conn_key and conn.conn == conn_pid
    end)
  end

  defp open_conn(key, uri, state, %{proxy: {proxy_host, proxy_port}} = opts) do
    connect_opts =
      uri
      |> destination_opts()
      |> add_http2_opts(uri.scheme, Map.get(opts, :tls_opts, []))

    with open_opts <- Map.delete(opts, :tls_opts),
         {:ok, conn} <- API.open(proxy_host, proxy_port, open_opts),
         {:ok, _} <- API.await_up(conn),
         stream <- API.connect(conn, connect_opts),
         {:response, :fin, 200, _} <- API.await(conn, stream),
         state <-
           put_in(state.conns[key], %Conn{
             conn: conn,
             gun_state: :up,
             conn_state: :active,
             last_reference: :os.system_time(:second)
           }) do
      {:noreply, state}
    else
      error ->
        Logger.warn(
          "Received error on opening connection with http proxy #{uri.scheme}://#{
            compose_uri(uri)
          }: #{inspect(error)}"
        )

        {:noreply, state}
    end
  end

  defp open_conn(key, uri, state, %{proxy: {proxy_type, proxy_host, proxy_port}} = opts) do
    version =
      proxy_type
      |> to_string()
      |> String.last()
      |> case do
        "4" -> 4
        _ -> 5
      end

    socks_opts =
      uri
      |> destination_opts()
      |> add_http2_opts(uri.scheme, Map.get(opts, :tls_opts, []))
      |> Map.put(:version, version)

    opts =
      opts
      |> Map.put(:protocols, [:socks])
      |> Map.put(:socks_opts, socks_opts)

    with {:ok, conn} <- API.open(proxy_host, proxy_port, opts),
         {:ok, _} <- API.await_up(conn),
         state <-
           put_in(state.conns[key], %Conn{
             conn: conn,
             gun_state: :up,
             conn_state: :active,
             last_reference: :os.system_time(:second)
           }) do
      {:noreply, state}
    else
      error ->
        Logger.warn(
          "Received error on opening connection with socks proxy #{uri.scheme}://#{
            compose_uri(uri)
          }: #{inspect(error)}"
        )

        {:noreply, state}
    end
  end

  defp open_conn(key, %URI{host: host, port: port} = uri, state, opts) do
    Logger.debug("opening conn #{compose_uri(uri)}")
    {_type, host} = Pleroma.HTTP.Adapter.domain_or_ip(host)

    with {:ok, conn} <- API.open(host, port, opts),
         {:ok, _} <- API.await_up(conn),
         state <-
           put_in(state.conns[key], %Conn{
             conn: conn,
             gun_state: :up,
             conn_state: :active,
             last_reference: :os.system_time(:second)
           }) do
      Logger.debug("new conn opened #{compose_uri(uri)}")
      Logger.debug("replying to the call #{compose_uri(uri)}")
      {:noreply, state}
    else
      error ->
        Logger.warn(
          "Received error on opening connection #{uri.scheme}://#{compose_uri(uri)}: #{
            inspect(error)
          }"
        )

        {:noreply, state}
    end
  end

  defp destination_opts(%URI{host: host, port: port}) do
    {_type, host} = Pleroma.HTTP.Adapter.domain_or_ip(host)
    %{host: host, port: port}
  end

  defp add_http2_opts(opts, "https", tls_opts) do
    Map.merge(opts, %{protocols: [:http2], transport: :tls, tls_opts: tls_opts})
  end

  defp add_http2_opts(opts, _, _), do: opts

  @spec get_unused_conns(map()) :: [{domain(), conn()}]
  def get_unused_conns(conns) do
    conns
    |> Enum.filter(fn {_k, v} ->
      v.conn_state == :idle and v.used_by == []
    end)
    |> Enum.sort(fn {_x_k, x}, {_y_k, y} ->
      x.crf <= y.crf and x.last_reference <= y.last_reference
    end)
  end

  defp try_to_open_conn(key, uri, state, opts) do
    Logger.debug("try to open conn #{compose_uri(uri)}")

    with [{close_key, least_used} | _conns] <- get_unused_conns(state.conns),
         :ok <- API.close(least_used.conn),
         state <-
           put_in(
             state.conns,
             Map.delete(state.conns, close_key)
           ) do
      Logger.debug(
        "least used conn found and closed #{inspect(least_used.conn)} #{compose_uri(uri)}"
      )

      open_conn(key, uri, state, opts)
    else
      [] -> {:noreply, state}
    end
  end

  def crf(current, steps, crf) do
    1 + :math.pow(0.5, current / steps) * crf
  end

  def compose_uri(%URI{} = uri), do: "#{uri.host}#{uri.path}"
end
