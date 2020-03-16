# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool.Connections do
  use GenServer

  alias Pleroma.Config
  alias Pleroma.Gun

  require Logger

  @type domain :: String.t()
  @type conn :: Pleroma.Gun.Conn.t()

  @type t :: %__MODULE__{
          conns: %{domain() => conn()},
          opts: keyword()
        }

  defstruct conns: %{}, opts: []

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
    timeout = Config.get([:connections_pool, :checkin_timeout], 250)

    GenServer.call(name, {:checkin, uri}, timeout)
  end

  @spec alive?(atom()) :: boolean()
  def alive?(name) do
    if pid = Process.whereis(name) do
      Process.alive?(pid)
    else
      false
    end
  end

  @spec get_state(atom()) :: t()
  def get_state(name) do
    GenServer.call(name, :state)
  end

  @spec count(atom()) :: pos_integer()
  def count(name) do
    GenServer.call(name, :count)
  end

  @spec get_unused_conns(atom()) :: [{domain(), conn()}]
  def get_unused_conns(name) do
    GenServer.call(name, :unused_conns)
  end

  @spec checkout(pid(), pid(), atom()) :: :ok
  def checkout(conn, pid, name) do
    GenServer.cast(name, {:checkout, conn, pid})
  end

  @spec add_conn(atom(), String.t(), Pleroma.Gun.Conn.t()) :: :ok
  def add_conn(name, key, conn) do
    GenServer.cast(name, {:add_conn, key, conn})
  end

  @spec remove_conn(atom(), String.t()) :: :ok
  def remove_conn(name, key) do
    GenServer.cast(name, {:remove_conn, key})
  end

  @impl true
  def handle_cast({:add_conn, key, conn}, state) do
    state = put_in(state.conns[key], conn)

    Process.monitor(conn.conn)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:checkout, conn_pid, pid}, state) do
    state =
      with true <- Process.alive?(conn_pid),
           {key, conn} <- find_conn(state.conns, conn_pid),
           used_by <- List.keydelete(conn.used_by, pid, 0) do
        conn_state = if used_by == [], do: :idle, else: conn.conn_state

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
  def handle_cast({:remove_conn, key}, state) do
    state = put_in(state.conns, Map.delete(state.conns, key))
    {:noreply, state}
  end

  @impl true
  def handle_call({:checkin, uri}, from, state) do
    key = "#{uri.scheme}:#{uri.host}:#{uri.port}"

    case state.conns[key] do
      %{conn: pid, gun_state: :up} = conn ->
        time = :os.system_time(:second)
        last_reference = time - conn.last_reference
        crf = crf(last_reference, 100, conn.crf)

        state =
          put_in(state.conns[key], %{
            conn
            | last_reference: time,
              crf: crf,
              conn_state: :active,
              used_by: [from | conn.used_by]
          })

        {:reply, pid, state}

      %{gun_state: :down} ->
        {:reply, nil, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, Enum.count(state.conns), state}
  end

  @impl true
  def handle_call(:unused_conns, _from, state) do
    unused_conns =
      state.conns
      |> Enum.filter(&filter_conns/1)
      |> Enum.sort(&sort_conns/2)

    {:reply, unused_conns, state}
  end

  defp filter_conns({_, %{conn_state: :idle, used_by: []}}), do: true
  defp filter_conns(_), do: false

  defp sort_conns({_, c1}, {_, c2}) do
    c1.crf <= c2.crf and c1.last_reference <= c2.last_reference
  end

  defp find_conn_from_gun_info(conns, pid) do
    # TODO: temp fix for gun MatchError https://github.com/ninenines/gun/issues/222
    # TODO: REMOVE LATER
    try do
      %{origin_host: host, origin_scheme: scheme, origin_port: port} = Gun.info(pid)

      host =
        case :inet.ntoa(host) do
          {:error, :einval} -> host
          ip -> ip
        end

      key = "#{scheme}:#{host}:#{port}"
      find_conn(conns, pid, key)
    rescue
      MatcheError -> find_conn(conns, pid)
    end
  end

  @impl true
  def handle_info({:gun_up, conn_pid, _protocol}, state) do
    state =
      with {key, conn} <- find_conn_from_gun_info(state.conns, conn_pid),
           {true, key} <- {Process.alive?(conn_pid), key} do
        put_in(state.conns[key], %{
          conn
          | gun_state: :up,
            conn_state: :active,
            retries: 0
        })
      else
        {false, key} ->
          put_in(
            state.conns,
            Map.delete(state.conns, key)
          )

        nil ->
          :ok = Gun.close(conn_pid)

          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_down, conn_pid, _protocol, _reason, _killed}, state) do
    retries = Config.get([:connections_pool, :retry], 1)
    # we can't get info on this pid, because pid is dead
    state =
      with {key, conn} <- find_conn(state.conns, conn_pid),
           {true, key} <- {Process.alive?(conn_pid), key} do
        if conn.retries == retries do
          :ok = Gun.close(conn.conn)

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
        {false, key} ->
          put_in(
            state.conns,
            Map.delete(state.conns, key)
          )

        nil ->
          Logger.debug(":gun_down for conn which isn't found in state")

          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, conn_pid, reason}, state) do
    Logger.debug("received DOWM message for #{inspect(conn_pid)} reason -> #{inspect(reason)}")

    state =
      with {key, conn} <- find_conn(state.conns, conn_pid) do
        Enum.each(conn.used_by, fn {pid, _ref} ->
          Process.exit(pid, reason)
        end)

        put_in(
          state.conns,
          Map.delete(state.conns, key)
        )
      else
        nil ->
          Logger.debug(":DOWN for conn which isn't found in state")

          state
      end

    {:noreply, state}
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

  def crf(current, steps, crf) do
    1 + :math.pow(0.5, current / steps) * crf
  end
end
