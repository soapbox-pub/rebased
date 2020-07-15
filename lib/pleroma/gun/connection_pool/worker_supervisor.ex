defmodule Pleroma.Gun.ConnectionPool.WorkerSupervisor do
  @moduledoc "Supervisor for pool workers. Does not do anything except enforce max connection limit"

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: Pleroma.Config.get([:connections_pool, :max_connections])
    )
  end

  def start_worker(opts) do
    case DynamicSupervisor.start_child(__MODULE__, {Pleroma.Gun.ConnectionPool.Worker, opts}) do
      {:error, :max_children} ->
        case free_pool() do
          :ok ->
            start_worker(opts)

          :error ->
            :telemetry.execute([:pleroma, :connection_pool, :provision_failure], %{opts: opts})
            {:error, :pool_full}
        end

      res ->
        res
    end
  end

  @registry Pleroma.Gun.ConnectionPool
  @enforcer_key "enforcer"
  defp free_pool do
    case Registry.lookup(@registry, @enforcer_key) do
      [] ->
        pid =
          spawn(fn ->
            {:ok, _pid} = Registry.register(@registry, @enforcer_key, nil)
            max_connections = Pleroma.Config.get([:connections_pool, :max_connections])

            reclaim_max =
              [:connections_pool, :reclaim_multiplier]
              |> Pleroma.Config.get()
              |> Kernel.*(max_connections)
              |> round
              |> max(1)

            :telemetry.execute([:pleroma, :connection_pool, :reclaim, :start], %{}, %{
              max_connections: max_connections,
              reclaim_max: reclaim_max
            })

            # :ets.fun2ms(
            # fn {_, {worker_pid, {_, used_by, crf, last_reference}}} when used_by == [] ->
            #   {worker_pid, crf, last_reference} end)
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
                :telemetry.execute(
                  [:pleroma, :connection_pool, :reclaim, :stop],
                  %{reclaimed_count: 0},
                  %{
                    max_connections: max_connections
                  }
                )

                exit(:no_unused_conns)

              unused_conns ->
                reclaimed =
                  unused_conns
                  |> Enum.sort(fn {_pid1, crf1, last_reference1},
                                  {_pid2, crf2, last_reference2} ->
                    crf1 <= crf2 and last_reference1 <= last_reference2
                  end)
                  |> Enum.take(reclaim_max)

                reclaimed
                |> Enum.each(fn {pid, _, _} ->
                  DynamicSupervisor.terminate_child(__MODULE__, pid)
                end)

                :telemetry.execute(
                  [:pleroma, :connection_pool, :reclaim, :stop],
                  %{reclaimed_count: Enum.count(reclaimed)},
                  %{max_connections: max_connections}
                )
            end
          end)

        wait_for_enforcer_finish(pid)

      [{pid, _}] ->
        wait_for_enforcer_finish(pid)
    end
  end

  defp wait_for_enforcer_finish(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, :no_unused_conns} ->
        :error

      {:DOWN, ^ref, :process, ^pid, :normal} ->
        :ok
    end
  end
end
