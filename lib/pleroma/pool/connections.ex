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
  def handle_cast({:remove_conn, key}, state) do
    state = put_in(state.conns, Map.delete(state.conns, key))
    {:noreply, state}
  end

  @impl true
  def handle_call({:checkin, uri}, from, state) do
    key = "#{uri.scheme}:#{uri.host}:#{uri.port}"
    Logger.debug("checkin #{key}")

    case state.conns[key] do
      %{conn: conn, gun_state: :up} = current_conn ->
        Logger.debug("reusing conn #{key}")

        time = :os.system_time(:second)
        last_reference = time - current_conn.last_reference
        current_crf = crf(last_reference, 100, current_conn.crf)

        state =
          put_in(state.conns[key], %{
            current_conn
            | last_reference: time,
              crf: current_crf,
              conn_state: :active,
              used_by: [from | current_conn.used_by]
          })

        {:reply, conn, state}

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
      |> Enum.filter(fn {_k, v} ->
        v.conn_state == :idle and v.used_by == []
      end)
      |> Enum.sort(fn {_x_k, x}, {_y_k, y} ->
        x.crf <= y.crf and x.last_reference <= y.last_reference
      end)

    {:reply, unused_conns, state}
  end

  @impl true
  def handle_info({:gun_up, conn_pid, _protocol}, state) do
    state =
      with conn_key when is_binary(conn_key) <- compose_key_gun_info(conn_pid),
           {key, conn} <- find_conn(state.conns, conn_pid, conn_key),
           {true, key} <- {Process.alive?(conn_pid), key} do
        time = :os.system_time(:second)
        last_reference = time - conn.last_reference
        current_crf = crf(last_reference, 100, conn.crf)

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

        {false, key} ->
          Logger.debug(":gun_up message for closed conn #{inspect(conn_pid)}")

          put_in(
            state.conns,
            Map.delete(state.conns, key)
          )

        nil ->
          Logger.debug(":gun_up message for conn which is not found in state")

          :ok = API.close(conn_pid)

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
        {false, key} ->
          # gun can send gun_down for closed conn, maybe connection is not closed yet
          Logger.debug(":gun_down message for closed conn #{inspect(conn_pid)}")

          put_in(
            state.conns,
            Map.delete(state.conns, key)
          )

        nil ->
          Logger.debug(":gun_down message for conn which is not found in state")

          :ok = API.close(conn_pid)

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
          Logger.debug(":DOWN message for conn which is not found in state")

          state
      end

    {:noreply, state}
  end

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

  def crf(current, steps, crf) do
    1 + :math.pow(0.5, current / steps) * crf
  end

  def compose_uri_log(%URI{scheme: scheme, host: host, path: path}) do
    "#{scheme}://#{host}#{path}"
  end
end
