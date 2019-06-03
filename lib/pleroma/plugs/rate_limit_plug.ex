# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimitPlug do
  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    enabled? = Pleroma.Config.get([:app_account_creation, :enabled])

    case check_rate(conn, Map.put(opts, :enabled, enabled?)) do
      {:ok, _count} -> conn
      {:error, _count} -> render_error(conn)
      %Plug.Conn{} = conn -> conn
    end
  end

  defp check_rate(conn, %{enabled: true} = opts) do
    max_requests = opts[:max_requests]
    bucket_name = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    ExRated.check_rate(bucket_name, opts[:interval] * 1000, max_requests)
  end

  defp check_rate(conn, _), do: conn

  defp render_error(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Rate limit exceeded."})
    |> halt()
  end
end
