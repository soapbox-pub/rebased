# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Federator.RetryQueue do
  use GenServer

  require Logger

  def init(args) do
    queue_table = :ets.new(:pleroma_retry_queue, [:bag, :protected])

    {:ok, %{args | queue_table: queue_table, running_jobs: :sets.new()}}
  end

  def start_link do
    enabled =
      if Pleroma.Config.get(:env) == :test,
        do: true,
        else: Pleroma.Config.get([__MODULE__, :enabled], false)

    if enabled do
      Logger.info("Starting retry queue")

      linkres =
        GenServer.start_link(
          __MODULE__,
          %{delivered: 0, dropped: 0, queue_table: nil, running_jobs: nil},
          name: __MODULE__
        )

      maybe_kickoff_timer()
      linkres
    else
      Logger.info("Retry queue disabled")
      :ignore
    end
  end

  def enqueue(data, transport, retries \\ 0) do
    GenServer.cast(__MODULE__, {:maybe_enqueue, data, transport, retries + 1})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats)
  end

  def get_retry_params(retries) do
    if retries > Pleroma.Config.get([__MODULE__, :max_retries]) do
      {:drop, "Max retries reached"}
    else
      {:retry, growth_function(retries)}
    end
  end

  def get_retry_timer_interval do
    Pleroma.Config.get([:retry_queue, :interval], 1000)
  end

  defp ets_count_expires(table, current_time) do
    :ets.select_count(
      table,
      [
        {
          {:"$1", :"$2"},
          [{:"=<", :"$1", {:const, current_time}}],
          [true]
        }
      ]
    )
  end

  defp ets_pop_n_expired(table, current_time, desired) do
    {popped, _continuation} =
      :ets.select(
        table,
        [
          {
            {:"$1", :"$2"},
            [{:"=<", :"$1", {:const, current_time}}],
            [:"$_"]
          }
        ],
        desired
      )

    popped
    |> Enum.each(fn e ->
      :ets.delete_object(table, e)
    end)

    popped
  end

  def maybe_start_job(running_jobs, queue_table) do
    # we don't want to hit the ets or the DateTime more times than we have to
    # could optimize slightly further by not using the count, and instead grabbing
    # up to N objects early...
    current_time = DateTime.to_unix(DateTime.utc_now())
    n_running_jobs = :sets.size(running_jobs)

    if n_running_jobs < Pleroma.Config.get([__MODULE__, :max_jobs]) do
      n_ready_jobs = ets_count_expires(queue_table, current_time)

      if n_ready_jobs > 0 do
        # figure out how many we could start
        available_job_slots = Pleroma.Config.get([__MODULE__, :max_jobs]) - n_running_jobs
        start_n_jobs(running_jobs, queue_table, current_time, available_job_slots)
      else
        running_jobs
      end
    else
      running_jobs
    end
  end

  defp start_n_jobs(running_jobs, _queue_table, _current_time, 0) do
    running_jobs
  end

  defp start_n_jobs(running_jobs, queue_table, current_time, available_job_slots)
       when available_job_slots > 0 do
    candidates = ets_pop_n_expired(queue_table, current_time, available_job_slots)

    candidates
    |> List.foldl(running_jobs, fn {_, e}, rj ->
      {:ok, pid} = Task.start(fn -> worker(e) end)
      mref = Process.monitor(pid)
      :sets.add_element(mref, rj)
    end)
  end

  def worker({:send, data, transport, retries}) do
    case transport.publish_one(data) do
      {:ok, _} ->
        GenServer.cast(__MODULE__, :inc_delivered)
        :delivered

      {:error, _reason} ->
        enqueue(data, transport, retries)
        :retry
    end
  end

  def handle_call(:get_stats, _from, %{delivered: delivery_count, dropped: drop_count} = state) do
    {:reply, %{delivered: delivery_count, dropped: drop_count}, state}
  end

  def handle_call(:reset_stats, _from, %{delivered: delivery_count, dropped: drop_count} = state) do
    {:reply, %{delivered: delivery_count, dropped: drop_count},
     %{state | delivered: 0, dropped: 0}}
  end

  def handle_cast(:reset_stats, state) do
    {:noreply, %{state | delivered: 0, dropped: 0}}
  end

  def handle_cast(
        {:maybe_enqueue, data, transport, retries},
        %{dropped: drop_count, queue_table: queue_table, running_jobs: running_jobs} = state
      ) do
    case get_retry_params(retries) do
      {:retry, timeout} ->
        :ets.insert(queue_table, {timeout, {:send, data, transport, retries}})
        running_jobs = maybe_start_job(running_jobs, queue_table)
        {:noreply, %{state | running_jobs: running_jobs}}

      {:drop, message} ->
        Logger.debug(message)
        {:noreply, %{state | dropped: drop_count + 1}}
    end
  end

  def handle_cast(:kickoff_timer, state) do
    retry_interval = get_retry_timer_interval()
    Process.send_after(__MODULE__, :retry_timer_run, retry_interval)
    {:noreply, state}
  end

  def handle_cast(:inc_delivered, %{delivered: delivery_count} = state) do
    {:noreply, %{state | delivered: delivery_count + 1}}
  end

  def handle_cast(:inc_dropped, %{dropped: drop_count} = state) do
    {:noreply, %{state | dropped: drop_count + 1}}
  end

  def handle_info({:send, data, transport, retries}, %{delivered: delivery_count} = state) do
    case transport.publish_one(data) do
      {:ok, _} ->
        {:noreply, %{state | delivered: delivery_count + 1}}

      {:error, _reason} ->
        enqueue(data, transport, retries)
        {:noreply, state}
    end
  end

  def handle_info(
        :retry_timer_run,
        %{queue_table: queue_table, running_jobs: running_jobs} = state
      ) do
    maybe_kickoff_timer()
    running_jobs = maybe_start_job(running_jobs, queue_table)
    {:noreply, %{state | running_jobs: running_jobs}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    %{running_jobs: running_jobs, queue_table: queue_table} = state
    running_jobs = :sets.del_element(ref, running_jobs)
    running_jobs = maybe_start_job(running_jobs, queue_table)
    {:noreply, %{state | running_jobs: running_jobs}}
  end

  def handle_info(unknown, state) do
    Logger.debug("RetryQueue: don't know what to do with #{inspect(unknown)}, ignoring")
    {:noreply, state}
  end

  if Pleroma.Config.get(:env) == :test do
    defp growth_function(_retries) do
      _shutit = Pleroma.Config.get([__MODULE__, :initial_timeout])
      DateTime.to_unix(DateTime.utc_now()) - 1
    end
  else
    defp growth_function(retries) do
      round(Pleroma.Config.get([__MODULE__, :initial_timeout]) * :math.pow(retries, 3)) +
        DateTime.to_unix(DateTime.utc_now())
    end
  end

  defp maybe_kickoff_timer do
    GenServer.cast(__MODULE__, :kickoff_timer)
  end
end
