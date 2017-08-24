defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller
  alias Pleroma.Web

  def help_test(conn, _params) do
    json(conn, "ok")
  end

  def config(conn, _params) do
    json(conn, %{
          site: %{
            name: Web.base_url,
            server: Web.base_url,
            textlimit: 5000
          }
    })
  end
end
