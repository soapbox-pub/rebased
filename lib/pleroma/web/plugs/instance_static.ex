# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.InstanceStatic do
  require Pleroma.Constants
  import Plug.Conn, only: [put_resp_header: 3]

  @moduledoc """
  This is a shim to call `Plug.Static` but with runtime `from` configuration.

  Mountpoints are defined directly in the module to avoid calling the configuration for every request including non-static ones.
  """
  @behaviour Plug

  def file_path(path) do
    instance_path =
      Path.join(Pleroma.Config.get([:instance, :static_dir], "instance/static/"), path)

    frontend_path = Pleroma.Web.Plugs.FrontendStatic.file_path(path, :primary)

    (File.exists?(instance_path) && instance_path) ||
      (frontend_path && File.exists?(frontend_path) && frontend_path) ||
      Path.join(Application.app_dir(:pleroma, "priv/static/"), path)
  end

  def init(opts) do
    opts
    |> Keyword.put(:from, "__unconfigured_instance_static_plug")
    |> Plug.Static.init()
  end

  for only <- Pleroma.Constants.static_only_files() do
    def call(%{request_path: "/" <> unquote(only) <> _} = conn, opts) do
      call_static(
        conn,
        opts,
        Pleroma.Config.get([:instance, :static_dir], "instance/static")
      )
    end
  end

  def call(conn, _) do
    conn
  end

  defp call_static(conn, opts, from) do
    # Prevent content-type spoofing by setting content_types: false
    opts =
      opts
      |> Map.put(:from, from)
      |> Map.put(:content_types, false)

    conn = set_content_type(conn, conn.request_path)

    # Call Plug.Static with our sanitized content-type
    Plug.Static.call(conn, opts)
  end

  defp set_content_type(conn, "/emoji/" <> filepath) do
    real_mime = MIME.from_path(filepath)

    clean_mime =
      Pleroma.Web.Plugs.Utils.get_safe_mime_type(%{allowed_mime_types: ["image"]}, real_mime)

    put_resp_header(conn, "content-type", clean_mime)
  end

  defp set_content_type(conn, filepath) do
    real_mime = MIME.from_path(filepath)
    put_resp_header(conn, "content-type", real_mime)
  end
end

# I think this needs to be uncleaned except for emoji.
