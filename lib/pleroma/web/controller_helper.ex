defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  def json_response(conn, status, json) do
    conn
    |> put_status(status)
    |> json(json)
  end
end
