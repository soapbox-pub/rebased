# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.StatsWorker do
  @moduledoc """
  The worker to update peers statistics.
  """

  use Oban.Worker, queue: "background"

  @impl Oban.Worker
  def perform(_opts, _job) do
    Pleroma.Stats.do_collect()
  end
end
