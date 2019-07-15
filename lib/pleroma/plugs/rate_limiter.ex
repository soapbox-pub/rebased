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

  To disable a limiter set its value to `nil`.

  ### Example

      config :pleroma, :rate_limit,
        one: {1000, 10},
        two: [{10_000, 10}, {10_000, 50}],
        foobar: nil

  Here we have three limiters:

  * `one` which is not over 10req/1s
  * `two` which has two limits: 10req/10s for unauthenticated users and 50req/10s for authenticated users
  * `foobar` which is disabled

  ## Usage

  AllowedSyntax:

      plug(Pleroma.Plugs.RateLimiter, :limiter_name)
      plug(Pleroma.Plugs.RateLimiter, {:limiter_name, options})

  Allowed options:

      * `bucket_name` overrides bucket name (e.g. to have a separate limit for a set of actions)
      * `params` appends values of specified request params (e.g. ["id"]) to bucket name

  Inside a controller:

      plug(Pleroma.Plugs.RateLimiter, :one when action == :one)
      plug(Pleroma.Plugs.RateLimiter, :two when action in [:two, :three])

      plug(
        Pleroma.Plugs.RateLimiter,
        {:status_id_action, bucket_name: "status_id_action:fav_unfav", params: ["id"]}
        when action in ~w(fav_status unfav_status)a
      )

  or inside a router pipeline:

      pipeline :api do
        ...
        plug(Pleroma.Plugs.RateLimiter, :one)
        ...
      end
  """
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn

  alias Pleroma.User

  def init(limiter_name) when is_atom(limiter_name) do
    init({limiter_name, []})
  end

  def init({limiter_name, opts}) do
    case Pleroma.Config.get([:rate_limit, limiter_name]) do
      nil -> nil
      config -> {limiter_name, config, opts}
    end
  end

  # Do not limit if there is no limiter configuration
  def call(conn, nil), do: conn

  def call(conn, settings) do
    case check_rate(conn, settings) do
      {:ok, _count} ->
        conn

      {:error, _count} ->
        render_throttled_error(conn)
    end
  end

  defp bucket_name(conn, limiter_name, opts) do
    bucket_name = opts[:bucket_name] || limiter_name

    if params_names = opts[:params] do
      params_values = for p <- Enum.sort(params_names), do: conn.params[p]
      Enum.join([bucket_name] ++ params_values, ":")
    else
      bucket_name
    end
  end

  defp check_rate(
         %{assigns: %{user: %User{id: user_id}}} = conn,
         {limiter_name, [_, {scale, limit}], opts}
       ) do
    bucket_name = bucket_name(conn, limiter_name, opts)
    ExRated.check_rate("#{bucket_name}:#{user_id}", scale, limit)
  end

  defp check_rate(conn, {limiter_name, [{scale, limit} | _], opts}) do
    bucket_name = bucket_name(conn, limiter_name, opts)
    ExRated.check_rate("#{bucket_name}:#{ip(conn)}", scale, limit)
  end

  defp check_rate(conn, {limiter_name, {scale, limit}, opts}) do
    check_rate(conn, {limiter_name, [{scale, limit}, {scale, limit}], opts})
  end

  def ip(%{remote_ip: remote_ip}) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp render_throttled_error(conn) do
    conn
    |> render_error(:too_many_requests, "Throttled")
    |> halt()
  end
end
