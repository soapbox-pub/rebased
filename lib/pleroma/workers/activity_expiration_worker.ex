# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ActivityExpirationWorker do
  # Note: `max_attempts` is intended to be overridden in `new/2` call
  use Oban.Worker,
    queue: "activity_expiration",
    max_attempts: 1

  use Pleroma.Workers.WorkerHelper, queue: "activity_expiration"

  @impl Oban.Worker
  def perform(
        %{
          "op" => "activity_expiration",
          "activity_expiration_id" => activity_expiration_id
        },
        _job
      ) do
    Pleroma.ActivityExpirationWorker.perform(:execute, activity_expiration_id)
  end
end
