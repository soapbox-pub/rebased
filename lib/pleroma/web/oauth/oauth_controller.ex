defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.OAuth.{Authorization, Token, App}
  alias Pleroma.{Repo, User}
  alias Comeonin.Pbkdf2

  def authorize(conn, params) do
    render conn, "show.html", %{
      response_type: params["response_type"],
      client_id: params["client_id"],
      scope: params["scope"],
      redirect_uri: params["redirect_uri"],
      state: params["state"]
    }
  end

  def create_authorization(conn, %{"authorization" => %{"name" => name, "password" => password, "client_id" => client_id, "redirect_uri" => redirect_uri} = params}) do
    with %User{} = user <- User.get_cached_by_nickname(name),
         true <- Pbkdf2.checkpw(password, user.password_hash),
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         {:ok, auth} <- Authorization.create_authorization(app, user) do
      if redirect_uri == "urn:ietf:wg:oauth:2.0:oob" do
        render conn, "results.html", %{
          auth: auth
        }
      else
        connector = if String.contains?(redirect_uri, "?"), do: "&", else: "?"
        url = "#{redirect_uri}#{connector}code=#{auth.token}"
        url = if params["state"] do
          url <> "&state=#{params["state"]}"
        else
          url
        end
        redirect(conn, external: url)
      end
    end
  end

  # TODO
  # - proper scope handling
  def token_exchange(conn, %{"grant_type" => "authorization_code"} = params) do
    with %App{} = app <- Repo.get_by(App, client_id: params["client_id"], client_secret: params["client_secret"]),
         fixed_token = fix_padding(params["code"]),
         %Authorization{} = auth <- Repo.get_by(Authorization, token: fixed_token, app_id: app.id),
         {:ok, token} <- Token.exchange_token(app, auth) do
      response = %{
        token_type: "Bearer",
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_in: 60 * 10,
        scope: "read write follow"
      }
      json(conn, response)
    else
      _error -> json(conn, %{error: "Invalid credentials"})
    end
  end

  defp fix_padding(token) do
    token
    |> Base.url_decode64!(padding: false)
    |> Base.url_encode64
  end
end
