# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.UploaderController do
  use Pleroma.Web, :controller

  alias Pleroma.Uploaders.Uploader

  def callback(conn, %{"upload_path" => upload_path} = params) do
    process_callback(conn, :global.whereis_name({Uploader, upload_path}), params)
  end

  defp process_callback(conn, pid, params) when is_pid(pid) do
    send(pid, {Uploader, self(), conn, params})

    receive do
      {Uploader, conn} -> conn
    end
  end

  defp process_callback(conn, _, _) do
    render_error(conn, :bad_request, "bad request")
  end
end
