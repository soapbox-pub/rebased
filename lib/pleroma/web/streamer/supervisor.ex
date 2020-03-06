# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    children = [
      {Pleroma.Web.Streamer.State, args},
      {Pleroma.Web.Streamer.Ping, args},
      :poolboy.child_spec(:streamer_worker, poolboy_config())
    ]

    opts = [strategy: :one_for_one, name: Pleroma.Web.Streamer.Supervisor]
    Supervisor.init(children, opts)
  end

  defp poolboy_config do
    opts =
      Pleroma.Config.get(:streamer,
        workers: 3,
        overflow_workers: 2
      )

    [
      {:name, {:local, :streamer_worker}},
      {:worker_module, Pleroma.Web.Streamer.Worker},
      {:size, opts[:workers]},
      {:max_overflow, opts[:overflow_workers]}
    ]
  end
end
