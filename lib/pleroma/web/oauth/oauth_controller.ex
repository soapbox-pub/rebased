# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Registration
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Web.ControllerHelper, only: [oauth_scopes: 2]

  if Pleroma.Config.get([:auth, :oauth_consumer_enabled]), do: plug(Ueberauth)

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

  def create_authorization(
        conn,
        %{
          "authorization" => %{"redirect_uri" => redirect_uri} = auth_params
        } = params,
        opts \\ []
      ) do
    with {:ok, auth} <-
           (opts[:auth] && {:ok, opts[:auth]}) ||
             do_create_authorization(conn, params, opts[:user]) do
      redirect_uri = redirect_uri(conn, redirect_uri)

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
        conn
        |> put_flash(:error, "Permissions not specified.")
        |> put_status(:unauthorized)
        |> authorize(auth_params)

      {:auth_active, false} ->
        conn
        |> put_flash(:error, "Account confirmation pending.")
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
    with {_, {:ok, %User{} = user}} <- {:get_user, Authenticator.get_user(conn, params)},
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
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Account confirmation pending"})

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

  def prepare_request(conn, %{"provider" => provider} = params) do
    scope =
      oauth_scopes(params, [])
      |> Enum.join(" ")

    state =
      params
      |> Map.delete("scopes")
      |> Map.put("scope", scope)
      |> Poison.encode!()

    params =
      params
      |> Map.drop(~w(scope scopes client_id redirect_uri))
      |> Map.put("state", state)

    redirect(conn, to: o_auth_path(conn, :request, provider, params))
  end

  def request(conn, params) do
    message =
      if params["provider"] do
        "Unsupported OAuth provider: #{params["provider"]}."
      else
        "Bad OAuth request."
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, params) do
    params = callback_params(params)
    messages = for e <- Map.get(failure, :errors, []), do: e.message
    message = Enum.join(messages, "; ")

    conn
    |> put_flash(:error, "Failed to authenticate: #{message}.")
    |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
  end

  def callback(conn, params) do
    params = callback_params(params)

    with {:ok, registration} <- Authenticator.get_registration(conn, params) do
      user = Repo.preload(registration, :user).user

      auth_params = %{
        "client_id" => params["client_id"],
        "redirect_uri" => params["redirect_uri"],
        "scopes" => oauth_scopes(params, nil)
      }

      if user do
        create_authorization(
          conn,
          %{"authorization" => auth_params},
          user: user
        )
      else
        registration_params =
          Map.merge(auth_params, %{
            "nickname" => Registration.nickname(registration),
            "email" => Registration.email(registration)
          })

        conn
        |> put_session(:registration_id, registration.id)
        |> redirect(to: o_auth_path(conn, :registration_details, registration_params))
      end
    else
      _ ->
        conn
        |> put_flash(:error, "Failed to set up user account.")
        |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
    end
  end

  defp callback_params(%{"state" => state} = params) do
    Map.merge(params, Poison.decode!(state))
  end

  def registration_details(conn, params) do
    render(conn, "register.html", %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      scopes: oauth_scopes(params, []),
      nickname: params["nickname"],
      email: params["email"]
    })
  end

  def register(conn, %{"op" => "connect"} = params) do
    create_authorization_params = %{
      "authorization" => Map.merge(params, %{"name" => params["auth_name"]})
    }

    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {:ok, auth} <- do_create_authorization(conn, create_authorization_params),
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      conn
      |> put_session_registration_id(nil)
      |> create_authorization(
        create_authorization_params,
        auth: auth
      )
    else
      _ ->
        conn
        |> put_flash(:error, "Unknown error, please try again.")
        |> redirect(to: o_auth_path(conn, :registration_details, params))
    end
  end

  def register(conn, params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {:ok, user} <- Authenticator.create_from_registration(conn, params, registration) do
      conn
      |> put_session_registration_id(nil)
      |> create_authorization(
        %{
          "authorization" => %{
            "client_id" => params["client_id"],
            "redirect_uri" => params["redirect_uri"],
            "scopes" => oauth_scopes(params, nil)
          }
        },
        user: user
      )
    else
      {:error, changeset} ->
        message =
          Enum.map(changeset.errors, fn {field, {error, _}} ->
            "#{field} #{error}"
          end)
          |> Enum.join("; ")

        message =
          String.replace(
            message,
            "ap_id has already been taken",
            "nickname has already been taken"
          )

        conn
        |> put_flash(:error, "Error: #{message}.")
        |> redirect(to: o_auth_path(conn, :registration_details, params))

      _ ->
        conn
        |> put_flash(:error, "Unknown error, please try again.")
        |> redirect(to: o_auth_path(conn, :registration_details, params))
    end
  end

  defp do_create_authorization(
         conn,
         %{
           "authorization" =>
             %{
               "client_id" => client_id,
               "redirect_uri" => redirect_uri
             } = auth_params
         } = params,
         user \\ nil
       ) do
    with {_, {:ok, %User{} = user}} <-
           {:get_user, (user && {:ok, user}) || Authenticator.get_user(conn, params)},
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         true <- redirect_uri in String.split(app.redirect_uris),
         scopes <- oauth_scopes(auth_params, []),
         {:unsupported_scopes, []} <- {:unsupported_scopes, scopes -- app.scopes},
         # Note: `scope` param is intentionally not optional in this context
         {:missing_scopes, false} <- {:missing_scopes, scopes == []},
         {:auth_active, true} <- {:auth_active, User.auth_active?(user)} do
      Authorization.create_authorization(app, user, scopes)
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

  # Special case: Local MastodonFE
  defp redirect_uri(conn, "."), do: mastodon_api_url(conn, :login)

  defp redirect_uri(_conn, redirect_uri), do: redirect_uri

  defp get_session_registration_id(conn), do: get_session(conn, :registration_id)

  defp put_session_registration_id(conn, registration_id),
    do: put_session(conn, :registration_id, registration_id)
end
