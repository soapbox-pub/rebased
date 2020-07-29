# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.FrontendStatic do
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
    frontend_type = Map.get(opts, :frontend_type, :primary)
    path = file_path("", frontend_type)

    if path do
      conn
      |> call_static(opts, path)
    else
      conn
    end
  end

  defp call_static(conn, opts, from) do
    opts =
      opts
      |> Map.put(:from, from)

    Plug.Static.call(conn, opts)
  end
end
