defmodule Pleroma.Gun.ConnectionPool do
  @registry __MODULE__

  def get_conn(uri, opts) do
    key = "#{uri.scheme}:#{uri.host}:#{uri.port}"

    case Registry.lookup(@registry, key) do
      # The key has already been registered, but connection is not up yet
      [{worker_pid, {nil, _used_by, _crf, _last_reference}}] ->
        get_gun_pid_from_worker(worker_pid)

      [{worker_pid, {gun_pid, _used_by, _crf, _last_reference}}] ->
        GenServer.cast(worker_pid, {:add_client, self(), false})
        {:ok, gun_pid}

      [] ->
        case enforce_pool_limits() do
          :ok ->
            # :gun.set_owner fails in :connected state for whatevever reason,
            # so we open the connection in the process directly and send it's pid back
            # We trust gun to handle timeouts by itself
            case GenServer.start(Pleroma.Gun.ConnectionPool.Worker, [uri, key, opts, self()],
                   timeout: :infinity
                 ) do
              {:ok, _worker_pid} ->
                receive do
                  {:conn_pid, pid} -> {:ok, pid}
                end

              {:error, {:error, {:already_registered, worker_pid}}} ->
                get_gun_pid_from_worker(worker_pid)

              err ->
                err
            end

          :error ->
            {:error, :pool_full}
        end
    end
  end

  @enforcer_key "enforcer"
  defp enforce_pool_limits() do
    max_connections = Pleroma.Config.get([:connections_pool, :max_connections])

    if Registry.count(@registry) >= max_connections do
      case Registry.lookup(@registry, @enforcer_key) do
        [] ->
          pid =
            spawn(fn ->
              {:ok, _pid} = Registry.register(@registry, @enforcer_key, nil)

              reclaim_max =
                [:connections_pool, :reclaim_multiplier]
                |> Pleroma.Config.get()
                |> Kernel.*(max_connections)
                |> round
                |> max(1)

              unused_conns =
                Registry.select(
                  @registry,
                  [
                    {{:_, :"$1", {:_, :"$2", :"$3", :"$4"}}, [{:==, :"$2", []}],
                     [{{:"$1", :"$3", :"$4"}}]}
                  ]
                )

              case unused_conns do
                [] ->
                  exit(:pool_full)

                unused_conns ->
                  unused_conns
                  |> Enum.sort(fn {_pid1, crf1, last_reference1},
                                  {_pid2, crf2, last_reference2} ->
                    crf1 <= crf2 and last_reference1 <= last_reference2
                  end)
                  |> Enum.take(reclaim_max)
                  |> Enum.each(fn {pid, _, _} -> GenServer.call(pid, :idle_close) end)
              end
            end)

          wait_for_enforcer_finish(pid)

        [{pid, _}] ->
          wait_for_enforcer_finish(pid)
      end
    else
      :ok
    end
  end

  defp wait_for_enforcer_finish(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, :pool_full} ->
        :error

      {:DOWN, ^ref, :process, ^pid, :normal} ->
        :ok
    end
  end

  defp get_gun_pid_from_worker(worker_pid) do
    # GenServer.call will block the process for timeout length if
    # the server crashes on startup (which will happen if gun fails to connect)
    # so instead we use cast + monitor

    ref = Process.monitor(worker_pid)
    GenServer.cast(worker_pid, {:add_client, self(), true})

    receive do
      {:conn_pid, pid} -> {:ok, pid}
      {:DOWN, ^ref, :process, ^worker_pid, reason} -> reason
    end
  end

  def release_conn(conn_pid) do
    query_result =
      Registry.select(@registry, [
        {{:_, :"$1", {:"$2", :_, :_, :_}}, [{:==, :"$2", conn_pid}], [:"$1"]}
      ])

    case query_result do
      [worker_pid] ->
        GenServer.cast(worker_pid, {:remove_client, self()})

      [] ->
        :ok
    end
  end
end
