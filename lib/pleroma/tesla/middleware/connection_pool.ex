# Pleroma: A lightweight social networking server
# Copyright © 2020 Pleroma Authors <https://pleroma.social/>
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

    case ConnectionPool.get_conn(uri, opts[:adapter]) do
      {:ok, conn_pid} ->
        adapter_opts = Keyword.merge(opts[:adapter], conn: conn_pid, close_conn: false)
        opts = Keyword.put(opts, :adapter, adapter_opts)
        env = %{env | opts: opts}
        res = Tesla.run(env, next)

        unless opts[:adapter][:body_as] == :chunks do
          ConnectionPool.release_conn(conn_pid)
        end

        res

      err ->
        err
    end
  end
end
