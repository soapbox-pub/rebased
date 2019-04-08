# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Web.ControllerHelper, only: [oauth_scopes: 2]

  if Pleroma.Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  plug(:fetch_session)
  plug(:fetch_flash)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  def authorize(%{assigns: %{token: %Token{} = token}} = conn, params) do
    if ControllerHelper.truthy_param?(params["force_login"]) do
      do_authorize(conn, params)
    else
      redirect_uri =
        if is_binary(params["redirect_uri"]) do
          params["redirect_uri"]
        else
          app = Repo.preload(token, :app).app

          app.redirect_uris
          |> String.split()
          |> Enum.at(0)
        end

      redirect(conn, external: redirect_uri(conn, redirect_uri))
    end
  end

  def authorize(conn, params), do: do_authorize(conn, params)

  defp do_authorize(conn, params) do
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
        %{"authorization" => auth_params} = params,
        opts \\ []
      ) do
    with {:ok, auth} <- do_create_authorization(conn, params, opts[:user]) do
      after_create_authorization(conn, auth, auth_params)
    else
      error ->
        handle_create_authorization_error(conn, error, auth_params)
    end
  end

  def after_create_authorization(conn, auth, %{"redirect_uri" => redirect_uri} = auth_params) do
    redirect_uri = redirect_uri(conn, redirect_uri)

    if redirect_uri == "urn:ietf:wg:oauth:2.0:oob" do
      render(conn, "results.html", %{
        auth: auth
      })
    else
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
  end

  defp handle_create_authorization_error(conn, {scopes_issue, _}, auth_params)
       when scopes_issue in [:unsupported_scopes, :missing_scopes] do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L39
    conn
    |> put_flash(:error, "This action is outside the authorized scopes")
    |> put_status(:unauthorized)
    |> authorize(auth_params)
  end

  defp handle_create_authorization_error(conn, {:auth_active, false}, auth_params) do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L76
    conn
    |> put_flash(:error, "Your login is missing a confirmed e-mail address")
    |> put_status(:forbidden)
    |> authorize(auth_params)
  end

  defp handle_create_authorization_error(conn, error, _auth_params) do
    Authenticator.handle_error(conn, error)
  end

  def token_exchange(conn, %{"grant_type" => "authorization_code"} = params) do
    with %App{} = app <- get_app_from_request(conn, params),
         fixed_token = fix_padding(params["code"]),
         %Authorization{} = auth <-
           Repo.get_by(Authorization, token: fixed_token, app_id: app.id),
         %User{} = user <- User.get_by_id(auth.user_id),
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
         {:user_active, true} <- {:user_active, !user.info.deactivated},
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

      {:user_active, false} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Your account is currently disabled"})

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

  @doc "Prepares OAuth request to provider for Ueberauth"
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

    # Handing the request to Ueberauth
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
      auth_params = Map.take(params, ~w(client_id redirect_uri scope scopes state))

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
        |> registration_details(registration_params)
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
      state: params["state"],
      scopes: oauth_scopes(params, []),
      nickname: params["nickname"],
      email: params["email"]
    })
  end

  def register(conn, %{"op" => "connect"} = params) do
    authorization_params = Map.put(params, "name", params["auth_name"])
    create_authorization_params = %{"authorization" => authorization_params}

    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {_, {:ok, auth}} <-
           {:create_authorization, do_create_authorization(conn, create_authorization_params)},
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      conn
      |> put_session_registration_id(nil)
      |> after_create_authorization(auth, authorization_params)
    else
      {:create_authorization, error} ->
        {:register, handle_create_authorization_error(conn, error, create_authorization_params)}

      _ ->
        {:register, :generic_error}
    end
  end

  def register(conn, %{"op" => "register"} = params) do
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
        |> put_status(:forbidden)
        |> put_flash(:error, "Error: #{message}.")
        |> registration_details(params)

      _ ->
        {:register, :generic_error}
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
