# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.RateLimiter.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_args) do
    children = [
      Pleroma.Web.Plugs.RateLimiter.LimiterSupervisor
    ]

    opts = [strategy: :one_for_one, name: Pleroma.Web.Streamer.Supervisor]
    Supervisor.init(children, opts)
  end
end
