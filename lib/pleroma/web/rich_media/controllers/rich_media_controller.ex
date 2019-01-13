defmodule Pleroma.Web.RichMedia.RichMediaController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  def parse(conn, %{"url" => url}) do
    case Pleroma.Web.RichMedia.Parser.parse(url) do
      {:ok, data} ->
        conn
        |> json_response(200, data)

      {:error, msg} ->
        conn
        |> json_response(404, msg)
    end
  end
end
