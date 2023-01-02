# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.FrontendStatic do
  require Pleroma.Constants

  @moduledoc """
  This is a shim to call `Plug.Static` but with runtime `from` configuration`. It dispatches to the different frontends.
  """
  @behaviour Plug

  def file_path(path, frontend_type \\ :primary) do
    if configuration = Pleroma.Config.get([:frontends, frontend_type]) do
      instance_static_path = Pleroma.Config.get([:instance, :static_dir], "instance/static")

      Path.join([
        instance_static_path,
        "frontends",
        configuration["name"],
        configuration["ref"],
        path
      ])
    else
      nil
    end
  end

  def init(opts) do
    opts
    |> Keyword.put(:from, "__unconfigured_frontend_static_plug")
    |> Plug.Static.init()
    |> Map.put(:frontend_type, opts[:frontend_type])
  end

  def call(conn, opts) do
    with false <- api_route?(conn.path_info),
         false <- invalid_path?(conn.path_info),
         frontend_type <- Map.get(opts, :frontend_type, :primary),
         path when not is_nil(path) <- file_path("", frontend_type) do
      call_static(conn, opts, path)
    else
      _ ->
        conn
    end
  end

  defp invalid_path?(list) do
    invalid_path?(list, :binary.compile_pattern(["/", "\\", ":", "\0"]))
  end

  defp invalid_path?([h | _], _match) when h in [".", "..", ""], do: true
  defp invalid_path?([h | t], match), do: String.contains?(h, match) or invalid_path?(t)
  defp invalid_path?([], _match), do: false

  defp api_route?([]), do: false

  defp api_route?([h | t]) do
    api_routes = Pleroma.Web.Router.get_api_routes()
    if h in api_routes, do: true, else: api_route?(t)
  end

  defp call_static(conn, opts, from) do
    opts = Map.put(opts, :from, from)
    Plug.Static.call(conn, opts)
  end
end
