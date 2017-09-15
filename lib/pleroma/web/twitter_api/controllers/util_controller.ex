defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller
  alias Pleroma.Web

  def help_test(conn, _params) do
    json(conn, "ok")
  end

  @instance Application.get_env(:pleroma, :instance)
  def config(conn, _params) do
    case get_format(conn) do
      "xml" ->
        response = """
        <config>
          <site>
            <name>#{Keyword.get(@instance, :name)}</name>
            <site>#{Web.base_url}</site>
            <textlimit>#{Keyword.get(@instance, :limit)}</textlimit>
          </site>
        </config>
        """
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ ->
        json(conn, %{
              site: %{
                name: Keyword.get(@instance, :name),
                server: Web.base_url,
                textlimit: Keyword.get(@instance, :limit)
              }
             })
    end
  end

  def version(conn, _params) do
    version = Keyword.get(@instance, :version)
    case get_format(conn) do
      "xml" ->
        response = "<version>#{version}</version>"
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ -> json(conn, version)
    end
  end
end
