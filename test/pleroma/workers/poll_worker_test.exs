# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PollWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mock
  import Pleroma.Factory

  alias Pleroma.Workers.PollWorker

  test "local poll ending notification job" do
    user = insert(:user)
    question = insert(:question, user: user)
    activity = insert(:question_activity, question: question, user: user)

    PollWorker.schedule_poll_end(activity)

    expected_job_args = %{"activity_id" => activity.id, "op" => "poll_end"}

    assert_enqueued(args: expected_job_args)

    with_mocks([
      {
        Pleroma.Web.Streamer,
        [],
        [
          stream: fn _, _ -> nil end
        ]
      },
      {
        Pleroma.Web.Push,
        [],
        [
          send: fn _ -> nil end
        ]
      }
    ]) do
      [job] = all_enqueued(worker: PollWorker)
      PollWorker.perform(job)

      # Ensure notifications were streamed out when job executes
      assert called(Pleroma.Web.Streamer.stream(["user", "user:notification"], :_))
      assert called(Pleroma.Web.Push.send(:_))

      # Skip refreshing polls for local activities
      assert activity.local

      refute_enqueued(
        worker: PollWorker,
        args: %{"op" => "refresh", "activity_id" => activity.id}
      )
    end
  end

  test "remote poll ending notification job schedules refresh" do
    user = insert(:user, local: false)
    question = insert(:question, user: user)
    activity = insert(:question_activity, question: question, user: user)

    PollWorker.schedule_poll_end(activity)

    expected_job_args = %{"activity_id" => activity.id, "op" => "poll_end"}

    assert_enqueued(args: expected_job_args)

    [job] = all_enqueued(worker: PollWorker)
    PollWorker.perform(job)

    refute activity.local

    assert_enqueued(
      worker: PollWorker,
      args: %{"op" => "refresh", "activity_id" => activity.id}
    )
  end

  test "poll refresh" do
    user = insert(:user, local: false)
    question = insert(:question, user: user)
    activity = insert(:question_activity, question: question)

    PollWorker.new(%{"op" => "refresh", "activity_id" => activity.id})
    |> Oban.insert()

    expected_job_args = %{"activity_id" => activity.id, "op" => "refresh"}

    assert_enqueued(args: expected_job_args)

    with_mocks([
      {
        Pleroma.Web.Streamer,
        [],
        [
          stream: fn _, _ -> nil end
        ]
      }
    ]) do
      [job] = all_enqueued(worker: PollWorker)
      PollWorker.perform(job)

      # Ensure updates are streamed out
      assert called(Pleroma.Web.Streamer.stream(["user", "list", "public", "public:local"], :_))
    end
  end
end
