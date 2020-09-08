# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MuteExpireWorker do
  use Pleroma.Workers.WorkerHelper, queue: "mute_expire"

  require Logger

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "unmute", "muter" => muter_id, "mutee" => mutee_id}}) do
    muter = Pleroma.User.get_by_id(muter_id)
    mutee = Pleroma.User.get_by_id(mutee_id)
    Pleroma.User.unmute(muter, mutee)
    :ok
  end

  def perform(any) do
    Logger.error("Got call to perform(#{inspect(any)})")
    :ok
  end
end
