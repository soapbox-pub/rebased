# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool.Supervisor do
  use Supervisor

  alias Pleroma.Pool

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    children =
      [
        %{
          id: Pool.Connections,
          start:
            {Pool.Connections, :start_link,
             [{:gun_connections, Pleroma.Config.get([:connections_pool])}]}
        }
      ] ++ pools()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp pools do
    for {pool_name, pool_opts} <- Pleroma.Config.get([:pools]) do
      pool_opts
      |> Keyword.put(:id, {Pool, pool_name})
      |> Keyword.put(:name, pool_name)
      |> Pool.child_spec()
    end
  end
end
