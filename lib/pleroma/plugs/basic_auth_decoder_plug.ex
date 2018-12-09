defmodule Pleroma.Plugs.BasicAuthDecoderPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with ["Basic " <> header] <- get_req_header(conn, "authorization"),
         {:ok, userinfo} <- Base.decode64(header),
         [username, password] <- String.split(userinfo, ":", parts: 2) do
      conn
      |> assign(:auth_credentials, %{
        username: username,
        password: password
      })
    else
      _ -> conn
    end
  end
end
