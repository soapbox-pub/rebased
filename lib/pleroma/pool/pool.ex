# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool do
  def child_spec(opts) do
    poolboy_opts =
      opts
      |> Keyword.put(:worker_module, Pleroma.Pool.Request)
      |> Keyword.put(:name, {:local, opts[:name]})
      |> Keyword.put(:size, opts[:size])
      |> Keyword.put(:max_overflow, opts[:max_overflow])

    %{
      id: opts[:id] || {__MODULE__, make_ref()},
      start: {:poolboy, :start_link, [poolboy_opts, [name: opts[:name]]]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end
end
