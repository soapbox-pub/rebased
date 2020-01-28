defmodule Restarter do
  use Application

  def start(_, _) do
    opts = [strategy: :one_for_one, name: Restarter.Supervisor]
    Supervisor.start_link([Restarter.Pleroma], opts)
  end
end
