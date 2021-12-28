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
    [:pleroma, :connection_pool, :client, :add],
    [:pleroma, :repo, :query]
  ]
  def attach do
    :telemetry.attach_many(
      "pleroma-logger",
      @events,
      &Pleroma.Telemetry.Logger.handle_event/4,
      []
    )
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

  def handle_event(
        [:pleroma, :repo, :query] = _name,
        %{query_time: query_time} = measurements,
        %{source: source} = metadata,
        config
      ) do
    logging_config = Pleroma.Config.get([:telemetry, :slow_queries_logging], [])

    if logging_config[:enabled] &&
         logging_config[:min_duration] &&
         query_time > logging_config[:min_duration] and
         (is_nil(logging_config[:exclude_sources]) or
            source not in logging_config[:exclude_sources]) do
      log_slow_query(measurements, metadata, config)
    else
      :ok
    end
  end

  defp log_slow_query(
         %{query_time: query_time} = _measurements,
         %{source: _source, query: query, params: query_params, repo: repo} = _metadata,
         _config
       ) do
    sql_explain =
      with {:ok, %{rows: explain_result_rows}} <-
             repo.query("EXPLAIN " <> query, query_params, log: false) do
        Enum.map_join(explain_result_rows, "\n", & &1)
      end

    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    pleroma_stacktrace =
      Enum.filter(stacktrace, fn
        {__MODULE__, _, _, _} ->
          false

        {mod, _, _, _} ->
          mod
          |> to_string()
          |> String.starts_with?("Elixir.Pleroma.")
      end)

    Logger.warn(fn ->
      """
      Slow query!

      Total time: #{round(query_time / 1_000)} ms

      #{query}

      #{inspect(query_params, limit: :infinity)}

      #{sql_explain}

      #{Exception.format_stacktrace(pleroma_stacktrace)}
      """
    end)
  end
end
