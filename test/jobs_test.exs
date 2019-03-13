# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.JobsTest do
  use ExUnit.Case, async: true

  alias Jobs.WorkerMock
  alias Pleroma.Jobs

  setup do
    state = %{
      queues: Enum.into([Jobs.create_queue(:testing)], %{}),
      refs: %{}
    }

    [state: state]
  end

  test "creates queue" do
    queue = Jobs.create_queue(:foobar)

    assert {:foobar, set} = queue
    assert :set == elem(set, 0) |> elem(0)
  end

  test "enqueues an element according to priority" do
    queue = [%{item: 1, priority: 2}]

    new_queue = Jobs.enqueue_sorted(queue, 2, 1)
    assert new_queue == [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    new_queue = Jobs.enqueue_sorted(queue, 2, 3)
    assert new_queue == [%{item: 1, priority: 2}, %{item: 2, priority: 3}]
  end

  test "pop first item" do
    queue = [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    assert {2, [%{item: 1, priority: 2}]} = Jobs.queue_pop(queue)
  end

  test "enqueue a job", %{state: state} do
    assert {:noreply, new_state} =
             Jobs.handle_cast({:enqueue, :testing, WorkerMock, [:test_job, :foo, :bar], 3}, state)

    assert %{queues: %{testing: {running_jobs, []}}, refs: _} = new_state
    assert :sets.size(running_jobs) == 1
    assert [ref] = :sets.to_list(running_jobs)
    assert %{refs: %{^ref => :testing}} = new_state
  end

  test "max jobs setting", %{state: state} do
    max_jobs = Pleroma.Config.get([Jobs, :testing, :max_jobs])

    {:noreply, state} =
      Enum.reduce(1..(max_jobs + 1), {:noreply, state}, fn _, {:noreply, state} ->
        Jobs.handle_cast({:enqueue, :testing, WorkerMock, [:test_job, :foo, :bar], 3}, state)
      end)

    assert %{
             queues: %{
               testing:
                 {running_jobs, [%{item: {WorkerMock, [:test_job, :foo, :bar]}, priority: 3}]}
             }
           } = state

    assert :sets.size(running_jobs) == max_jobs
  end

  test "remove job after it finished", %{state: state} do
    {:noreply, new_state} =
      Jobs.handle_cast({:enqueue, :testing, WorkerMock, [:test_job, :foo, :bar], 3}, state)

    %{queues: %{testing: {running_jobs, []}}} = new_state
    [ref] = :sets.to_list(running_jobs)

    assert {:noreply, %{queues: %{testing: {running_jobs, []}}, refs: %{}}} =
             Jobs.handle_info({:DOWN, ref, :process, nil, nil}, new_state)

    assert :sets.size(running_jobs) == 0
  end
end
