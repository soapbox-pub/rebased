# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.UserRefreshWorker do
  use Pleroma.Workers.WorkerHelper, queue: "background", max_attempts: 1, unique: [period: 300]

  alias Pleroma.User

  @impl Oban.Worker
  def perform(%Job{args: %{"ap_id" => ap_id}}) do
    User.fetch_by_ap_id(ap_id)
  end
end
