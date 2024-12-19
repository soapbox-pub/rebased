# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.UserRefreshWorker do
  use Oban.Worker, queue: :background, max_attempts: 1, unique: [period: :infinity]

  alias Pleroma.User

  @impl true
  def perform(%Job{args: %{"ap_id" => ap_id}}) do
    User.fetch_by_ap_id(ap_id)
  end

  @impl true
  def timeout(_job), do: :timer.seconds(15)
end
