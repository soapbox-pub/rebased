# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun.ConnectionPool do
  @registry __MODULE__

  alias Pleroma.Gun.ConnectionPool.WorkerSupervisor

  def children do
    [
      {Registry, keys: :unique, name: @registry},
      Pleroma.Gun.ConnectionPool.WorkerSupervisor
    ]
  end

  @spec get_conn(URI.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def get_conn(uri, opts) do
    key = "#{uri.scheme}:#{uri.host}:#{uri.port}"

    case Registry.lookup(@registry, key) do
      # The key has already been registered, but connection is not up yet
      [{worker_pid, nil}] ->
        get_gun_pid_from_worker(worker_pid, true)

      [{worker_pid, {gun_pid, _used_by, _crf, _last_reference}}] ->
        GenServer.call(worker_pid, :add_client)
        {:ok, gun_pid}

      [] ->
        # :gun.set_owner fails in :connected state for whatevever reason,
        # so we open the connection in the process directly and send it's pid back
        # We trust gun to handle timeouts by itself
        case WorkerSupervisor.start_worker([key, uri, opts, self()]) do
          {:ok, worker_pid} ->
            get_gun_pid_from_worker(worker_pid, false)

          {:error, {:already_started, worker_pid}} ->
            get_gun_pid_from_worker(worker_pid, true)

          err ->
            err
        end
    end
  end

  defp get_gun_pid_from_worker(worker_pid, register) do
    # GenServer.call will block the process for timeout length if
    # the server crashes on startup (which will happen if gun fails to connect)
    # so instead we use cast + monitor

    ref = Process.monitor(worker_pid)
    if register, do: GenServer.cast(worker_pid, {:add_client, self()})

    receive do
      {:conn_pid, pid} ->
        Process.demonitor(ref)
        {:ok, pid}

      {:DOWN, ^ref, :process, ^worker_pid, reason} ->
        case reason do
          {:shutdown, {:error, _} = error} -> error
          {:shutdown, error} -> {:error, error}
          _ -> {:error, reason}
        end
    end
  end

  @spec release_conn(pid()) :: :ok
  def release_conn(conn_pid) do
    # :ets.fun2ms(fn {_, {worker_pid, {gun_pid, _, _, _}}} when gun_pid == conn_pid ->
    #    worker_pid end)
    query_result =
      Registry.select(@registry, [
        {{:_, :"$1", {:"$2", :_, :_, :_}}, [{:==, :"$2", conn_pid}], [:"$1"]}
      ])

    case query_result do
      [worker_pid] ->
        GenServer.call(worker_pid, :remove_client)

      [] ->
        :ok
    end
  end
end
