defmodule Pleroma.Web.OEmbed.OEmbedController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo

  def url(conn, %{ "url" => uri} ) do
    conn
    |> put_resp_content_type("application/json")
    |> json(%{ status: "success"} )
  end
end