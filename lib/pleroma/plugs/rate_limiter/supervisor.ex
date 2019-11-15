defmodule Pleroma.Plugs.RateLimiter.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_args) do
    children = [
      Pleroma.Plugs.RateLimiter.LimiterSupervisor
    ]

    opts = [strategy: :one_for_one, name: Pleroma.Web.Streamer.Supervisor]
    Supervisor.init(children, opts)
  end
end
