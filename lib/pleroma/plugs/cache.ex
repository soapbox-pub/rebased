# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.Cache do
  @moduledoc """
  Caches successful GET responses.

  To enable the cache add the plug to a router pipeline or controller:

      plug(Pleroma.Plugs.Cache)

  ## Configuration

  To configure the plug you need to pass settings as the second argument to the `plug/2` macro:

      plug(Pleroma.Plugs.Cache, [ttl: nil, query_params: true])

  Available options:

  - `ttl`:  An expiration time (time-to-live). This value should be in milliseconds or `nil` to disable expiration. Defaults to `nil`.
  - `query_params`: Take URL query string into account (`true`), ignore it (`false`) or limit to specific params only (list). Defaults to `true`.
  - `tracking_fun`: A function that is called on successfull responses, no matter if the request is cached or not. It should accept a conn as the first argument and the value assigned to `tracking_fun_data` as the second.

  Additionally, you can overwrite the TTL inside a controller action by assigning `cache_ttl` to the connection struct:

      def index(conn, _params) do
        ttl = 60_000 # one minute

        conn
        |> assign(:cache_ttl, ttl)
        |> render("index.html")
      end

  """

  import Phoenix.Controller, only: [current_path: 1, json: 2]
  import Plug.Conn

  @behaviour Plug

  @defaults %{ttl: nil, query_params: true}

  @impl true
  def init([]), do: @defaults

  def init(opts) do
    opts = Map.new(opts)
    Map.merge(@defaults, opts)
  end

  @impl true
  def call(%{method: "GET"} = conn, opts) do
    key = cache_key(conn, opts)

    case Cachex.get(:web_resp_cache, key) do
      {:ok, nil} ->
        cache_resp(conn, opts)

      {:ok, {content_type, body, tracking_fun_data}} ->
        conn = opts.tracking_fun.(conn, tracking_fun_data)

        send_cached(conn, {content_type, body})

      {:ok, record} ->
        send_cached(conn, record)

      {atom, message} when atom in [:ignore, :error] ->
        render_error(conn, message)
    end
  end

  def call(conn, _), do: conn

  # full path including query params
  defp cache_key(conn, %{query_params: true}), do: current_path(conn)

  # request path without query params
  defp cache_key(conn, %{query_params: false}), do: conn.request_path

  # request path with specific query params
  defp cache_key(conn, %{query_params: query_params}) when is_list(query_params) do
    query_string =
      conn.params
      |> Map.take(query_params)
      |> URI.encode_query()

    conn.request_path <> "?" <> query_string
  end

  defp cache_resp(conn, opts) do
    register_before_send(conn, fn
      %{status: 200, resp_body: body} = conn ->
        ttl = Map.get(conn.assigns, :cache_ttl, opts.ttl)
        key = cache_key(conn, opts)
        content_type = content_type(conn)

        conn =
          unless opts[:tracking_fun] do
            Cachex.put(:web_resp_cache, key, {content_type, body}, ttl: ttl)
            conn
          else
            tracking_fun_data = Map.get(conn.assigns, :tracking_fun_data, nil)
            Cachex.put(:web_resp_cache, key, {content_type, body, tracking_fun_data}, ttl: ttl)

            opts.tracking_fun.(conn, tracking_fun_data)
          end

        put_resp_header(conn, "x-cache", "MISS from Pleroma")

      conn ->
        conn
    end)
  end

  defp content_type(conn) do
    conn
    |> Plug.Conn.get_resp_header("content-type")
    |> hd()
  end

  defp send_cached(conn, {content_type, body}) do
    conn
    |> put_resp_content_type(content_type, nil)
    |> put_resp_header("x-cache", "HIT from Pleroma")
    |> send_resp(:ok, body)
    |> halt()
  end

  defp render_error(conn, message) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: message})
    |> halt()
  end
end
