defmodule Pleroma.Plugs.OAuthPlug do
  import Plug.Conn
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn
  def call(conn, _) do
    token = case get_req_header(conn, "authorization") do
              ["Bearer " <> header] -> header
              _ -> get_session(conn, :oauth_token)
            end
    with token when not is_nil(token) <- token,
         %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         %User{} = user <- Repo.get(User, user_id),
         false <- !!user.info["deactivated"] do
      conn
      |> assign(:user, user)
    else
      _ -> conn
    end
  end
end
