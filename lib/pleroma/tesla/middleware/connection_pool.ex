# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tesla.Middleware.ConnectionPool do
  @moduledoc """
  Middleware to get/release connections from `Pleroma.Gun.ConnectionPool`
  """

  @behaviour Tesla.Middleware

  alias Pleroma.Gun.ConnectionPool

  @impl Tesla.Middleware
  def call(%Tesla.Env{url: url, opts: opts} = env, next, _) do
    uri = URI.parse(url)

    # Avoid leaking connections when the middleware is called twice
    # with body_as: :chunks. We assume only the middleware can set
    # opts[:adapter][:conn]
    if opts[:adapter][:conn] do
      ConnectionPool.release_conn(opts[:adapter][:conn])
    end

    case ConnectionPool.get_conn(uri, opts[:adapter]) do
      {:ok, conn_pid} ->
        adapter_opts = Keyword.merge(opts[:adapter], conn: conn_pid, close_conn: false)
        opts = Keyword.put(opts, :adapter, adapter_opts)
        env = %{env | opts: opts}

        case Tesla.run(env, next) do
          {:ok, env} ->
            unless opts[:adapter][:body_as] == :chunks do
              ConnectionPool.release_conn(conn_pid)
              {_, res} = pop_in(env.opts[:adapter][:conn])
              {:ok, res}
            else
              {:ok, env}
            end

          err ->
            ConnectionPool.release_conn(conn_pid)
            err
        end

      err ->
        err
    end
  end
end
