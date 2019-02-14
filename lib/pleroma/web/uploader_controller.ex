defmodule Pleroma.Web.UploaderController do
  use Pleroma.Web, :controller

  alias Pleroma.Uploaders.Uploader

  def callback(conn, %{"upload_path" => upload_path} = params) do
    process_callback(conn, :global.whereis_name({Uploader, upload_path}), params)
  end

  def callbacks(conn, _) do
    send_resp(conn, 400, "bad request")
  end

  defp process_callback(conn, pid, params) when is_pid(pid) do
    send(pid, {Uploader, self(), conn, params})

    receive do
      {Uploader, conn} -> conn
    end
  end

  defp process_callback(conn, _, _) do
    send_resp(conn, 400, "bad request")
  end
end
