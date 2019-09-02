# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ActivityExpirationWorker do
  use Pleroma.Workers.WorkerHelper, queue: "activity_expiration"

  @impl Oban.Worker
  def perform(
        %{
          "op" => "activity_expiration",
          "activity_expiration_id" => activity_expiration_id
        },
        _job
      ) do
    Pleroma.Daemons.ActivityExpirationDaemon.perform(:execute, activity_expiration_id)
  end
end
