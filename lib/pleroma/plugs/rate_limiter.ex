# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimiter do
  @moduledoc """

  ## Configuration

  A keyword list of rate limiters where a key is a limiter name and value is the limiter configuration. The basic configuration is a tuple where:

  * The first element: `scale` (Integer). The time scale in milliseconds.
  * The second element: `limit` (Integer). How many requests to limit in the time scale provided.

  It is also possible to have different limits for unauthenticated and authenticated users: the keyword value must be a list of two tuples where the first one is a config for unauthenticated users and the second one is for authenticated.

  ### Example

      config :pleroma, :rate_limit,
        one: {1000, 10},
        two: [{10_000, 10}, {10_000, 50}]

  Here we have two limiters: `one` which is not over 10req/1s and `two` which has two limits 10req/10s for unauthenticated users and 50req/10s for authenticated users.

  ## Usage

  Inside a controller:

      plug(Pleroma.Plugs.RateLimiter, :one when action == :one)
      plug(Pleroma.Plugs.RateLimiter, :two when action in [:two, :three])

  or inside a router pipiline:

      pipeline :api do
        ...
        plug(Pleroma.Plugs.RateLimiter, :one)
        ...
      end
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  alias Pleroma.User

  def init(limiter_name) do
    case Pleroma.Config.get([:rate_limit, limiter_name]) do
      nil -> nil
      config -> {limiter_name, config}
    end
  end

  # do not limit if there is no limiter configuration
  def call(conn, nil), do: conn

  def call(conn, opts) do
    case check_rate(conn, opts) do
      {:ok, _count} -> conn
      {:error, _count} -> render_error(conn)
    end
  end

  defp check_rate(%{assigns: %{user: %User{id: user_id}}}, {limiter_name, [_, {scale, limit}]}) do
    ExRated.check_rate("#{limiter_name}:#{user_id}", scale, limit)
  end

  defp check_rate(conn, {limiter_name, [{scale, limit} | _]}) do
    ExRated.check_rate("#{limiter_name}:#{ip(conn)}", scale, limit)
  end

  defp check_rate(conn, {limiter_name, {scale, limit}}) do
    check_rate(conn, {limiter_name, [{scale, limit}]})
  end

  def ip(%{remote_ip: remote_ip}) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp render_error(conn) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{error: "Throttled"})
    |> halt()
  end
end
