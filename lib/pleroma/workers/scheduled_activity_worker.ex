# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ScheduledActivityWorker do
  use Pleroma.Workers.WorkerHelper, queue: "scheduled_activities"

  @impl Oban.Worker
  def perform(%{"op" => "execute", "activity_id" => activity_id}, _job) do
    Pleroma.Daemons.ScheduledActivityDaemon.perform(:execute, activity_id)
  end
end
