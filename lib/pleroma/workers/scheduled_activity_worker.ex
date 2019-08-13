# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorker do
  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "scheduled_activities",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "execute", "activity_id" => activity_id}) do
    Pleroma.ScheduledActivityWorker.perform(:execute, activity_id)
  end
end
