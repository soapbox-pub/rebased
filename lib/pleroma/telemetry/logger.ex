# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Telemetry.Logger do
  @moduledoc "Transforms Pleroma telemetry events to logs"

  require Logger

  @events [
    [:pleroma, :connection_pool, :reclaim, :start],
    [:pleroma, :connection_pool, :reclaim, :stop],
    [:pleroma, :connection_pool, :provision_failure],
    [:pleroma, :connection_pool, :client, :dead],
    [:pleroma, :connection_pool, :client, :add]
  ]
  def attach do
    :telemetry.attach_many("pleroma-logger", @events, &handle_event/4, [])
  end

  # Passing anonymous functions instead of strings to logger is intentional,
  # that way strings won't be concatenated if the message is going to be thrown
  # out anyway due to higher log level configured

  def handle_event(
        [:pleroma, :connection_pool, :reclaim, :start],
        _,
        %{max_connections: max_connections, reclaim_max: reclaim_max},
        _
      ) do
    Logger.debug(fn ->
      "Connection pool is exhausted (reached #{max_connections} connections). Starting idle connection cleanup to reclaim as much as #{reclaim_max} connections"
    end)
  end

  def handle_event(
        [:pleroma, :connection_pool, :reclaim, :stop],
        %{reclaimed_count: 0},
        _,
        _
      ) do
    Logger.error(fn ->
      "Connection pool failed to reclaim any connections due to all of them being in use. It will have to drop requests for opening connections to new hosts"
    end)
  end

  def handle_event(
        [:pleroma, :connection_pool, :reclaim, :stop],
        %{reclaimed_count: reclaimed_count},
        _,
        _
      ) do
    Logger.debug(fn -> "Connection pool cleaned up #{reclaimed_count} idle connections" end)
  end

  def handle_event(
        [:pleroma, :connection_pool, :provision_failure],
        %{opts: [key | _]},
        _,
        _
      ) do
    Logger.error(fn ->
      "Connection pool had to refuse opening a connection to #{key} due to connection limit exhaustion"
    end)
  end

  def handle_event(
        [:pleroma, :connection_pool, :client, :dead],
        %{client_pid: client_pid, reason: reason},
        %{key: key},
        _
      ) do
    Logger.warn(fn ->
      "Pool worker for #{key}: Client #{inspect(client_pid)} died before releasing the connection with #{inspect(reason)}"
    end)
  end

  def handle_event(
        [:pleroma, :connection_pool, :client, :add],
        %{clients: [_, _ | _] = clients},
        %{key: key, protocol: :http},
        _
      ) do
    Logger.info(fn ->
      "Pool worker for #{key}: #{length(clients)} clients are using an HTTP1 connection at the same time, head-of-line blocking might occur."
    end)
  end

  def handle_event([:pleroma, :connection_pool, :client, :add], _, _, _), do: :ok
end
