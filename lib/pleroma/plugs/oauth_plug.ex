defmodule Pleroma.Plugs.OAuthPlug do
  import Plug.Conn
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn
  def call(conn, opts) do
    with ["Bearer " <> header] <- get_req_header(conn, "authorization"),
         %Token{user_id: user_id} <- Repo.get_by(Token, token: header),
         %User{} = user <- Repo.get(User, user_id) do
      conn
      |> assign(:user, user)
    else
      _ -> conn
    end
  end
end
