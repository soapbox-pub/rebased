# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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

  def start_worker(opts, retry \\ false) do
    case DynamicSupervisor.start_child(__MODULE__, {Pleroma.Gun.ConnectionPool.Worker, opts}) do
      {:error, :max_children} ->
        if retry or free_pool() == :error do
          :telemetry.execute([:pleroma, :connection_pool, :provision_failure], %{opts: opts})
          {:error, :pool_full}
        else
          start_worker(opts, true)
        end

      res ->
        res
    end
  end

  defp free_pool do
    wait_for_reclaimer_finish(Pleroma.Gun.ConnectionPool.Reclaimer.start_monitor())
  end

  defp wait_for_reclaimer_finish({pid, mon}) do
    receive do
      {:DOWN, ^mon, :process, ^pid, :no_unused_conns} ->
        :error

      {:DOWN, ^mon, :process, ^pid, :normal} ->
        :ok
    end
  end
end
