# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Web.ControllerHelper, only: [oauth_scopes: 2]

  plug(:fetch_session)
  plug(:fetch_flash)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  def authorize(conn, params) do
    app = Repo.get_by(App, client_id: params["client_id"])
    available_scopes = (app && app.scopes) || []
    scopes = oauth_scopes(params, nil) || available_scopes

    render(conn, Authenticator.auth_template(), %{
      response_type: params["response_type"],
      client_id: params["client_id"],
      available_scopes: available_scopes,
      scopes: scopes,
      redirect_uri: params["redirect_uri"],
      state: params["state"],
      params: params
    })
  end

  def create_authorization(conn, %{
        "authorization" =>
          %{
            "client_id" => client_id,
            "redirect_uri" => redirect_uri
          } = auth_params
      }) do
    with {_, {:ok, %User{} = user}} <- {:get_user, Authenticator.get_user(conn)},
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         true <- redirect_uri in String.split(app.redirect_uris),
         scopes <- oauth_scopes(auth_params, []),
         {:unsupported_scopes, []} <- {:unsupported_scopes, scopes -- app.scopes},
         # Note: `scope` param is intentionally not optional in this context
         {:missing_scopes, false} <- {:missing_scopes, scopes == []},
         {:auth_active, true} <- {:auth_active, User.auth_active?(user)},
         {:ok, auth} <- Authorization.create_authorization(app, user, scopes) do
      redirect_uri =
        if redirect_uri == "." do
          # Special case: Local MastodonFE
          mastodon_api_url(conn, :login)
        else
          redirect_uri
        end

      cond do
        redirect_uri == "urn:ietf:wg:oauth:2.0:oob" ->
          render(conn, "results.html", %{
            auth: auth
          })

        true ->
          connector = if String.contains?(redirect_uri, "?"), do: "&", else: "?"
          url = "#{redirect_uri}#{connector}"
          url_params = %{:code => auth.token}

          url_params =
            if auth_params["state"] do
              Map.put(url_params, :state, auth_params["state"])
            else
              url_params
            end

          url = "#{url}#{Plug.Conn.Query.encode(url_params)}"

          redirect(conn, external: url)
      end
    else
      {scopes_issue, _} when scopes_issue in [:unsupported_scopes, :missing_scopes] ->
        # Per https://github.com/tootsuite/mastodon/blob/
        #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L39
        conn
        |> put_flash(:error, "This action is outside the authorized scopes")
        |> put_status(:unauthorized)
        |> authorize(auth_params)

      {:auth_active, false} ->
        # Per https://github.com/tootsuite/mastodon/blob/
        #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L76
        conn
        |> put_flash(:error, "Your login is missing a confirmed e-mail address")
        |> put_status(:forbidden)
        |> authorize(auth_params)

      error ->
        Authenticator.handle_error(conn, error)
    end
  end

  def token_exchange(conn, %{"grant_type" => "authorization_code"} = params) do
    with %App{} = app <- get_app_from_request(conn, params),
         fixed_token = fix_padding(params["code"]),
         %Authorization{} = auth <-
           Repo.get_by(Authorization, token: fixed_token, app_id: app.id),
         %User{} = user <- Repo.get(User, auth.user_id),
         {:ok, token} <- Token.exchange_token(app, auth),
         {:ok, inserted_at} <- DateTime.from_naive(token.inserted_at, "Etc/UTC") do
      response = %{
        token_type: "Bearer",
        access_token: token.token,
        refresh_token: token.refresh_token,
        created_at: DateTime.to_unix(inserted_at),
        expires_in: 60 * 10,
        scope: Enum.join(token.scopes, " "),
        me: user.ap_id
      }

      json(conn, response)
    else
      _error ->
        put_status(conn, 400)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def token_exchange(
        conn,
        %{"grant_type" => "password"} = params
      ) do
    with {_, {:ok, %User{} = user}} <- {:get_user, Authenticator.get_user(conn)},
         %App{} = app <- get_app_from_request(conn, params),
         {:auth_active, true} <- {:auth_active, User.auth_active?(user)},
         scopes <- oauth_scopes(params, app.scopes),
         [] <- scopes -- app.scopes,
         true <- Enum.any?(scopes),
         {:ok, auth} <- Authorization.create_authorization(app, user, scopes),
         {:ok, token} <- Token.exchange_token(app, auth) do
      response = %{
        token_type: "Bearer",
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_in: 60 * 10,
        scope: Enum.join(token.scopes, " "),
        me: user.ap_id
      }

      json(conn, response)
    else
      {:auth_active, false} ->
        # Per https://github.com/tootsuite/mastodon/blob/
        #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L76
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Your login is missing a confirmed e-mail address"})

      _error ->
        put_status(conn, 400)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def token_exchange(
        conn,
        %{"grant_type" => "password", "name" => name, "password" => _password} = params
      ) do
    params =
      params
      |> Map.delete("name")
      |> Map.put("username", name)

    token_exchange(conn, params)
  end

  def token_revoke(conn, %{"token" => token} = params) do
    with %App{} = app <- get_app_from_request(conn, params),
         %Token{} = token <- Repo.get_by(Token, token: token, app_id: app.id),
         {:ok, %Token{}} <- Repo.delete(token) do
      json(conn, %{})
    else
      _error ->
        # RFC 7009: invalid tokens [in the request] do not cause an error response
        json(conn, %{})
    end
  end

  # XXX - for whatever reason our token arrives urlencoded, but Plug.Conn should be
  # decoding it.  Investigate sometime.
  defp fix_padding(token) do
    token
    |> URI.decode()
    |> Base.url_decode64!(padding: false)
    |> Base.url_encode64(padding: false)
  end

  defp get_app_from_request(conn, params) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    {client_id, client_secret} =
      with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
           {:ok, decoded} <- Base.decode64(encoded),
           [id, secret] <-
             String.split(decoded, ":")
             |> Enum.map(fn s -> URI.decode_www_form(s) end) do
        {id, secret}
      else
        _ -> {params["client_id"], params["client_secret"]}
      end

    if client_id && client_secret do
      Repo.get_by(
        App,
        client_id: client_id,
        client_secret: client_secret
      )
    else
      nil
    end
  end
end
