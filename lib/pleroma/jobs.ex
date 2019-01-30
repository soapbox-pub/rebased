# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Jobs do
  @moduledoc """
  A basic job queue
  """
  use GenServer

  require Logger

  def init(args) do
    {:ok, args}
  end

  def start_link do
    queues =
      Pleroma.Config.get(Pleroma.Jobs)
      |> Enum.map(fn {name, _} -> create_queue(name) end)
      |> Enum.into(%{})

    state = %{
      queues: queues,
      refs: %{}
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def create_queue(name) do
    {name, {:sets.new(), []}}
  end

  @doc """
  Enqueues a job.

  Returns `:ok`.

  ## Arguments

  - `queue_name` - a queue name(must be specified in the config).
  - `mod` - a worker module (must have `perform` function).
  - `args` - a list of arguments for the `perform` function of the worker module.
  - `priority` - a job priority (`0` by default).

  ## Examples

  Enqueue `Module.perform/0` with `priority=1`:

      iex> Pleroma.Jobs.enqueue(:example_queue, Module, [])
      :ok

  Enqueue `Module.perform(:job_name)` with `priority=5`:

      iex> Pleroma.Jobs.enqueue(:example_queue, Module, [:job_name], 5)
      :ok

  Enqueue `Module.perform(:another_job, data)` with `priority=1`:

      iex> data = "foobar"
      iex> Pleroma.Jobs.enqueue(:example_queue, Module, [:another_job, data])
      :ok

  Enqueue `Module.perform(:foobar_job, :foo, :bar, 42)` with `priority=1`:

      iex> Pleroma.Jobs.enqueue(:example_queue, Module, [:foobar_job, :foo, :bar, 42])
      :ok

  """

  def enqueue(queue_name, mod, args, priority \\ 1)

  if Mix.env() == :test do
    def enqueue(_queue_name, mod, args, _priority) do
      apply(mod, :perform, args)
    end
  else
    @spec enqueue(atom(), atom(), [any()], integer()) :: :ok
    def enqueue(queue_name, mod, args, priority) do
      GenServer.cast(__MODULE__, {:enqueue, queue_name, mod, args, priority})
    end
  end

  def handle_cast({:enqueue, queue_name, mod, args, priority}, state) do
    {running_jobs, queue} = state[:queues][queue_name]

    queue = enqueue_sorted(queue, {mod, args}, priority)

    state =
      state
      |> update_queue(queue_name, {running_jobs, queue})
      |> maybe_start_job(queue_name, running_jobs, queue)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    queue_name = state.refs[ref]

    {running_jobs, queue} = state[:queues][queue_name]

    running_jobs = :sets.del_element(ref, running_jobs)

    state =
      state
      |> remove_ref(ref)
      |> update_queue(queue_name, {running_jobs, queue})
      |> maybe_start_job(queue_name, running_jobs, queue)

    {:noreply, state}
  end

  def maybe_start_job(state, queue_name, running_jobs, queue) do
    if :sets.size(running_jobs) < Pleroma.Config.get([__MODULE__, queue_name, :max_jobs]) &&
         queue != [] do
      {{mod, args}, queue} = queue_pop(queue)
      {:ok, pid} = Task.start(fn -> apply(mod, :perform, args) end)
      mref = Process.monitor(pid)

      state
      |> add_ref(queue_name, mref)
      |> update_queue(queue_name, {:sets.add_element(mref, running_jobs), queue})
    else
      state
    end
  end

  def enqueue_sorted(queue, element, priority) do
    [%{item: element, priority: priority} | queue]
    |> Enum.sort_by(fn %{priority: priority} -> priority end)
  end

  def queue_pop([%{item: element} | queue]) do
    {element, queue}
  end

  defp add_ref(state, queue_name, ref) do
    refs = Map.put(state[:refs], ref, queue_name)
    Map.put(state, :refs, refs)
  end

  defp remove_ref(state, ref) do
    refs = Map.delete(state[:refs], ref)
    Map.put(state, :refs, refs)
  end

  defp update_queue(state, queue_name, data) do
    queues = Map.put(state[:queues], queue_name, data)
    Map.put(state, :queues, queues)
  end
end
