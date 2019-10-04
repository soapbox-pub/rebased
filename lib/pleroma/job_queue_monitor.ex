# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.JobQueueMonitor do
  use GenServer

  @initial_state %{workers: %{}, queues: %{}, processed_jobs: 0}
  @queue %{processed_jobs: 0, success: 0, failure: 0}
  @operation %{processed_jobs: 0, success: 0, failure: 0}

  def start_link(_) do
    GenServer.start_link(__MODULE__, @initial_state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :telemetry.attach("oban-monitor-failure", [:oban, :failure], &handle_event/4, nil)
    :telemetry.attach("oban-monitor-success", [:oban, :success], &handle_event/4, nil)

    {:ok, state}
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  def handle_event([:oban, status], %{duration: duration}, meta, _) do
    GenServer.cast(__MODULE__, {:process_event, status, duration, meta})
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:process_event, status, duration, meta}, state) do
    state =
      state
      |> Map.update!(:workers, fn workers ->
        workers
        |> Map.put_new(meta.worker, %{})
        |> Map.update!(meta.worker, &update_worker(&1, status, meta, duration))
      end)
      |> Map.update!(:queues, fn workers ->
        workers
        |> Map.put_new(meta.queue, @queue)
        |> Map.update!(meta.queue, &update_queue(&1, status, meta, duration))
      end)
      |> Map.update!(:processed_jobs, &(&1 + 1))

    {:noreply, state}
  end

  defp update_worker(worker, status, meta, duration) do
    worker
    |> Map.put_new(meta.args["op"], @operation)
    |> Map.update!(meta.args["op"], &update_op(&1, status, meta, duration))
  end

  defp update_op(op, :enqueue, _meta, _duration) do
    op
    |> Map.update!(:enqueued, &(&1 + 1))
  end

  defp update_op(op, status, _meta, _duration) do
    op
    |> Map.update!(:processed_jobs, &(&1 + 1))
    |> Map.update!(status, &(&1 + 1))
  end

  defp update_queue(queue, status, _meta, _duration) do
    queue
    |> Map.update!(:processed_jobs, &(&1 + 1))
    |> Map.update!(status, &(&1 + 1))
  end
end
