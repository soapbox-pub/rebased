# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.JobQueueMonitorTest do
  use ExUnit.Case, async: true

  alias Pleroma.JobQueueMonitor

  @success {:process_event, :success, 1337,
            %{
              args: %{"op" => "refresh_subscriptions"},
              attempt: 1,
              id: 339,
              max_attempts: 5,
              queue: "federator_outgoing",
              worker: "Pleroma.Workers.SubscriberWorker"
            }}

  @failure {:process_event, :failure, 22_521_134,
            %{
              args: %{"op" => "force_password_reset", "user_id" => "9nJG6n6Nbu7tj9GJX6"},
              attempt: 1,
              error: %RuntimeError{message: "oops"},
              id: 345,
              kind: :exception,
              max_attempts: 1,
              queue: "background",
              stack: [
                {Pleroma.Workers.BackgroundWorker, :perform, 2,
                 [file: 'lib/pleroma/workers/background_worker.ex', line: 31]},
                {Oban.Queue.Executor, :safe_call, 1,
                 [file: 'lib/oban/queue/executor.ex', line: 42]},
                {:timer, :tc, 3, [file: 'timer.erl', line: 197]},
                {Oban.Queue.Executor, :call, 2, [file: 'lib/oban/queue/executor.ex', line: 23]},
                {Task.Supervised, :invoke_mfa, 2, [file: 'lib/task/supervised.ex', line: 90]},
                {:proc_lib, :init_p_do_apply, 3, [file: 'proc_lib.erl', line: 249]}
              ],
              worker: "Pleroma.Workers.BackgroundWorker"
            }}

  test "stats/0" do
    assert %{processed_jobs: _, queues: _, workers: _} = JobQueueMonitor.stats()
  end

  test "handle_cast/2" do
    state = %{workers: %{}, queues: %{}, processed_jobs: 0}

    assert {:noreply, state} = JobQueueMonitor.handle_cast(@success, state)
    assert {:noreply, state} = JobQueueMonitor.handle_cast(@failure, state)
    assert {:noreply, state} = JobQueueMonitor.handle_cast(@success, state)
    assert {:noreply, state} = JobQueueMonitor.handle_cast(@failure, state)

    assert state == %{
             processed_jobs: 4,
             queues: %{
               "background" => %{failure: 2, processed_jobs: 2, success: 0},
               "federator_outgoing" => %{failure: 0, processed_jobs: 2, success: 2}
             },
             workers: %{
               "Pleroma.Workers.BackgroundWorker" => %{
                 "force_password_reset" => %{failure: 2, processed_jobs: 2, success: 0}
               },
               "Pleroma.Workers.SubscriberWorker" => %{
                 "refresh_subscriptions" => %{failure: 0, processed_jobs: 2, success: 2}
               }
             }
           }
  end
end
