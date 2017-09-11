defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller
  alias Pleroma.Web

  def help_test(conn, _params) do
    json(conn, "ok")
  end

  def config(conn, _params) do
    case get_format(conn) do
      "xml" ->
        response = """
        <config>
          <site>
            <name>#{Web.base_url}</name>
            <site>#{Web.base_url}</site>
            <textlimit>5000</textlimit>
          </site>
        </config>
        """
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ ->
        json(conn, %{
              site: %{
                name: Web.base_url,
                server: Web.base_url,
                textlimit: 5000
              }
             })
    end
  end

  def version(conn, _params) do
    case get_format(conn) do
      "xml" ->
        response = "<version>Pleroma Dev</version>"
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ -> json(conn, "Pleroma Dev")
    end
  end
end
