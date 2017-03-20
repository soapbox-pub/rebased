defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller

  alias Pleroma.Web.TwitterAPI.Representers.UserRepresenter

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    response = user |> UserRepresenter.to_json

    conn
    |> json_reply(200, response)
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end
end
