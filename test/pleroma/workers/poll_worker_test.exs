# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PollWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mock
  import Pleroma.Factory

  alias Pleroma.Workers.PollWorker

  test "poll notification job" do
    user = insert(:user)
    question = insert(:question, user: user)
    activity = insert(:question_activity, question: question)

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
    end
  end
end
