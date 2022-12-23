# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Helpers.UriHelper
  alias Pleroma.Maps
  alias Pleroma.MFA
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.WrapperAuthenticator, as: Authenticator
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.MFAController
  alias Pleroma.Web.OAuth.MFAView
  alias Pleroma.Web.OAuth.OAuthView
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OAuth.Token.Strategy.RefreshToken
  alias Pleroma.Web.OAuth.Token.Strategy.Revoke, as: RevokeToken
  alias Pleroma.Web.Plugs.RateLimiter
  alias Pleroma.Web.Utils.Params

  require Logger

  if Pleroma.Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  plug(:fetch_session)
  plug(:fetch_flash)

  plug(:skip_auth)

  plug(RateLimiter, [name: :authentication] when action == :create_authorization)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  @oob_token_redirect_uri "urn:ietf:wg:oauth:2.0:oob"

  # Note: this definition is only called from error-handling methods with `conn.params` as 2nd arg
  def authorize(%Plug.Conn{} = conn, %{"authorization" => _} = params) do
    {auth_attrs, params} = Map.pop(params, "authorization")
    authorize(conn, Map.merge(params, auth_attrs))
  end

  def authorize(%Plug.Conn{assigns: %{token: %Token{}}} = conn, %{"force_login" => _} = params) do
    if Params.truthy_param?(params["force_login"]) do
      do_authorize(conn, params)
    else
      handle_existing_authorization(conn, params)
    end
  end

  # Note: the token is set in oauth_plug, but the token and client do not always go together.
  # For example, MastodonFE's token is set if user requests with another client,
  # after user already authorized to MastodonFE.
  # So we have to check client and token.
  def authorize(
        %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
        %{"client_id" => client_id} = params
      ) do
    with %Token{} = t <- Repo.get_by(Token, token: token.token) |> Repo.preload(:app),
         ^client_id <- t.app.client_id do
      handle_existing_authorization(conn, params)
    else
      _ -> do_authorize(conn, params)
    end
  end

  def authorize(%Plug.Conn{} = conn, params), do: do_authorize(conn, params)

  defp do_authorize(%Plug.Conn{} = conn, params) do
    app = Repo.get_by(App, client_id: params["client_id"])
    available_scopes = (app && app.scopes) || []
    scopes = Scopes.fetch_scopes(params, available_scopes)

    user =
      with %{assigns: %{user: %User{} = user}} <- conn do
        user
      else
        _ -> nil
      end

    scopes =
      if scopes == [] do
        available_scopes
      else
        scopes
      end

    # Note: `params` might differ from `conn.params`; use `@params` not `@conn.params` in template
    render(conn, Authenticator.auth_template(), %{
      user: user,
      app: app && Map.delete(app, :client_secret),
      response_type: params["response_type"],
      client_id: params["client_id"],
      available_scopes: available_scopes,
      scopes: scopes,
      redirect_uri: params["redirect_uri"],
      state: params["state"],
      params: params
    })
  end

  defp handle_existing_authorization(
         %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
         %{"redirect_uri" => @oob_token_redirect_uri}
       ) do
    render(conn, "oob_token_exists.html", %{token: token})
  end

  defp handle_existing_authorization(
         %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
         %{} = params
       ) do
    app = Repo.preload(token, :app).app

    redirect_uri =
      if is_binary(params["redirect_uri"]) do
        params["redirect_uri"]
      else
        default_redirect_uri(app)
      end

    if redirect_uri in String.split(app.redirect_uris) do
      redirect_uri = redirect_uri(conn, redirect_uri)
      url_params = %{access_token: token.token}
      url_params = Maps.put_if_present(url_params, :state, params["state"])
      url = UriHelper.modify_uri_params(redirect_uri, url_params)
      redirect(conn, external: url)
    else
      conn
      |> put_flash(:error, dgettext("errors", "Unlisted redirect_uri."))
      |> redirect(external: redirect_uri(conn, redirect_uri))
    end
  end

  def create_authorization(_, _, opts \\ [])

  def create_authorization(%Plug.Conn{assigns: %{user: %User{} = user}} = conn, params, []) do
    create_authorization(conn, params, user: user)
  end

  def create_authorization(%Plug.Conn{} = conn, %{"authorization" => _} = params, opts) do
    with {:ok, auth, user} <- do_create_authorization(conn, params, opts[:user]),
         {:mfa_required, _, _, false} <- {:mfa_required, user, auth, MFA.require?(user)} do
      after_create_authorization(conn, auth, params)
    else
      error ->
        handle_create_authorization_error(conn, error, params)
    end
  end

  def after_create_authorization(%Plug.Conn{} = conn, %Authorization{} = auth, %{
        "authorization" => %{"redirect_uri" => @oob_token_redirect_uri}
      }) do
    # Enforcing the view to reuse the template when calling from other controllers
    conn
    |> put_view(OAuthView)
    |> render("oob_authorization_created.html", %{auth: auth})
  end

  def after_create_authorization(%Plug.Conn{} = conn, %Authorization{} = auth, %{
        "authorization" => %{"redirect_uri" => redirect_uri} = auth_attrs
      }) do
    app = Repo.preload(auth, :app).app

    # An extra safety measure before we redirect (also done in `do_create_authorization/2`)
    if redirect_uri in String.split(app.redirect_uris) do
      redirect_uri = redirect_uri(conn, redirect_uri)
      url_params = %{code: auth.token}
      url_params = Maps.put_if_present(url_params, :state, auth_attrs["state"])
      url = UriHelper.modify_uri_params(redirect_uri, url_params)
      redirect(conn, external: url)
    else
      conn
      |> put_flash(:error, dgettext("errors", "Unlisted redirect_uri."))
      |> redirect(external: redirect_uri(conn, redirect_uri))
    end
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:error, scopes_issue},
         %{"authorization" => _} = params
       )
       when scopes_issue in [:unsupported_scopes, :missing_scopes] do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L39
    conn
    |> put_flash(:error, dgettext("errors", "This action is outside the authorized scopes"))
    |> put_status(:unauthorized)
    |> authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :confirmation_pending},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Your login is missing a confirmed e-mail address"))
    |> put_status(:forbidden)
    |> authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:mfa_required, user, auth, _},
         params
       ) do
    {:ok, token} = MFA.Token.create(user, auth)

    data = %{
      "mfa_token" => token.token,
      "redirect_uri" => params["authorization"]["redirect_uri"],
      "state" => params["authorization"]["state"]
    }

    MFAController.show(conn, data)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :password_reset_pending},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Password reset is required"))
    |> put_status(:forbidden)
    |> authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :deactivated},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Your account is currently disabled"))
    |> put_status(:forbidden)
    |> authorize(params)
  end

  defp handle_create_authorization_error(%Plug.Conn{} = conn, error, %{"authorization" => _}) do
    Authenticator.handle_error(conn, error)
  end

  @doc "Renew access_token with refresh_token"
  def token_exchange(
        %Plug.Conn{} = conn,
        %{"grant_type" => "refresh_token", "refresh_token" => token} = _params
      ) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         {:ok, %{user: user} = token} <- Token.get_by_refresh_token(app, token),
         {:ok, token} <- RefreshToken.grant(token) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      _error -> render_invalid_credentials_error(conn)
    end
  end

  def token_exchange(%Plug.Conn{} = conn, %{"grant_type" => "authorization_code"} = params) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         fixed_token = Token.Utils.fix_padding(params["code"]),
         {:ok, auth} <- Authorization.get_by_token(app, fixed_token),
         %User{} = user <- User.get_cached_by_id(auth.user_id),
         {:ok, token} <- Token.exchange_token(app, auth) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      error ->
        handle_token_exchange_error(conn, error)
    end
  end

  def token_exchange(
        %Plug.Conn{} = conn,
        %{"grant_type" => "password"} = params
      ) do
    with {:ok, %User{} = user} <- Authenticator.get_user(conn),
         {:ok, app} <- Token.Utils.fetch_app(conn),
         requested_scopes <- Scopes.fetch_scopes(params, app.scopes),
         {:ok, token} <- login(user, app, requested_scopes) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      error ->
        handle_token_exchange_error(conn, error)
    end
  end

  def token_exchange(
        %Plug.Conn{} = conn,
        %{"grant_type" => "password", "name" => name, "password" => _password} = params
      ) do
    params =
      params
      |> Map.delete("name")
      |> Map.put("username", name)

    token_exchange(conn, params)
  end

  def token_exchange(%Plug.Conn{} = conn, %{"grant_type" => "client_credentials"} = _params) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         {:ok, auth} <- Authorization.create_authorization(app, %User{}),
         {:ok, token} <- Token.exchange_token(app, auth) do
      after_token_exchange(conn, %{token: token})
    else
      _error ->
        handle_token_exchange_error(conn, :invalid_credentails)
    end
  end

  # Bad request
  def token_exchange(%Plug.Conn{} = conn, params), do: bad_request(conn, params)

  def after_token_exchange(%Plug.Conn{} = conn, %{token: token} = view_params) do
    conn
    |> AuthHelper.put_session_token(token.token)
    |> json(OAuthView.render("token.json", view_params))
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:mfa_required, user, auth, _}) do
    conn
    |> put_status(:forbidden)
    |> json(build_and_response_mfa_token(user, auth))
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :deactivated}) do
    render_error(
      conn,
      :forbidden,
      "Your account is currently disabled",
      %{},
      "account_is_disabled"
    )
  end

  defp handle_token_exchange_error(
         %Plug.Conn{} = conn,
         {:account_status, :password_reset_pending}
       ) do
    render_error(
      conn,
      :forbidden,
      "Password reset is required",
      %{},
      "password_reset_required"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :confirmation_pending}) do
    render_error(
      conn,
      :forbidden,
      "Your login is missing a confirmed e-mail address",
      %{},
      "missing_confirmed_email"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :approval_pending}) do
    render_error(
      conn,
      :forbidden,
      "Your account is awaiting approval.",
      %{},
      "awaiting_approval"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, _error) do
    render_invalid_credentials_error(conn)
  end

  def token_revoke(%Plug.Conn{} = conn, %{"token" => token}) do
    with {:ok, %Token{} = oauth_token} <- Token.get_by_token(token),
         {:ok, oauth_token} <- RevokeToken.revoke(oauth_token) do
      conn =
        with session_token = AuthHelper.get_session_token(conn),
             %Token{token: ^session_token} <- oauth_token do
          AuthHelper.delete_session_token(conn)
        else
          _ -> conn
        end

      json(conn, %{})
    else
      _error ->
        # RFC 7009: invalid tokens [in the request] do not cause an error response
        json(conn, %{})
    end
  end

  def token_revoke(%Plug.Conn{} = conn, params), do: bad_request(conn, params)

  # Response for bad request
  defp bad_request(%Plug.Conn{} = conn, _) do
    render_error(conn, :internal_server_error, "Bad request")
  end

  @doc "Prepares OAuth request to provider for Ueberauth"
  def prepare_request(%Plug.Conn{} = conn, %{
        "provider" => provider,
        "authorization" => auth_attrs
      }) do
    scope =
      auth_attrs
      |> Scopes.fetch_scopes([])
      |> Scopes.to_string()

    state =
      auth_attrs
      |> Map.delete("scopes")
      |> Map.put("scope", scope)
      |> Jason.encode!()

    params =
      auth_attrs
      |> Map.drop(~w(scope scopes client_id redirect_uri))
      |> Map.put("state", state)

    # Handing the request to Ueberauth
    redirect(conn, to: Routes.o_auth_path(conn, :request, provider, params))
  end

  def request(%Plug.Conn{} = conn, params) do
    message =
      if params["provider"] do
        dgettext("errors", "Unsupported OAuth provider: %{provider}.",
          provider: params["provider"]
        )
      else
        dgettext("errors", "Bad OAuth request.")
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  def callback(%Plug.Conn{assigns: %{ueberauth_failure: failure}} = conn, params) do
    params = callback_params(params)
    messages = for e <- Map.get(failure, :errors, []), do: e.message
    message = Enum.join(messages, "; ")

    conn
    |> put_flash(
      :error,
      dgettext("errors", "Failed to authenticate: %{message}.", message: message)
    )
    |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
  end

  def callback(%Plug.Conn{} = conn, params) do
    params = callback_params(params)

    with {:ok, registration} <- Authenticator.get_registration(conn) do
      auth_attrs = Map.take(params, ~w(client_id redirect_uri scope scopes state))

      case Repo.get_assoc(registration, :user) do
        {:ok, user} ->
          create_authorization(conn, %{"authorization" => auth_attrs}, user: user)

        _ ->
          registration_params =
            Map.merge(auth_attrs, %{
              "nickname" => Registration.nickname(registration),
              "email" => Registration.email(registration)
            })

          conn
          |> put_session_registration_id(registration.id)
          |> registration_details(%{"authorization" => registration_params})
      end
    else
      error ->
        Logger.debug(inspect(["OAUTH_ERROR", error, conn.assigns]))

        conn
        |> put_flash(:error, dgettext("errors", "Failed to set up user account."))
        |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
    end
  end

  defp callback_params(%{"state" => state} = params) do
    Map.merge(params, Jason.decode!(state))
  end

  def registration_details(%Plug.Conn{} = conn, %{"authorization" => auth_attrs}) do
    render(conn, "register.html", %{
      client_id: auth_attrs["client_id"],
      redirect_uri: auth_attrs["redirect_uri"],
      state: auth_attrs["state"],
      scopes: Scopes.fetch_scopes(auth_attrs, []),
      nickname: auth_attrs["nickname"],
      email: auth_attrs["email"]
    })
  end

  def register(%Plug.Conn{} = conn, %{"authorization" => _, "op" => "connect"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {_, {:ok, auth, _user}} <-
           {:create_authorization, do_create_authorization(conn, params)},
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      conn
      |> put_session_registration_id(nil)
      |> after_create_authorization(auth, params)
    else
      {:create_authorization, error} ->
        {:register, handle_create_authorization_error(conn, error, params)}

      _ ->
        {:register, :generic_error}
    end
  end

  def register(%Plug.Conn{} = conn, %{"authorization" => _, "op" => "register"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {:ok, user} <- Authenticator.create_from_registration(conn, registration) do
      conn
      |> put_session_registration_id(nil)
      |> create_authorization(
        params,
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

  defp do_create_authorization(conn, auth_attrs, user \\ nil)

  defp do_create_authorization(
         %Plug.Conn{} = conn,
         %{
           "authorization" =>
             %{
               "client_id" => client_id,
               "redirect_uri" => redirect_uri
             } = auth_attrs
         },
         user
       ) do
    with {_, {:ok, %User{} = user}} <-
           {:get_user, (user && {:ok, user}) || Authenticator.get_user(conn)},
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         true <- redirect_uri in String.split(app.redirect_uris),
         requested_scopes <- Scopes.fetch_scopes(auth_attrs, app.scopes),
         {:ok, auth} <- do_create_authorization(user, app, requested_scopes) do
      {:ok, auth, user}
    end
  end

  defp do_create_authorization(%User{} = user, %App{} = app, requested_scopes)
       when is_list(requested_scopes) do
    with {:account_status, :active} <- {:account_status, User.account_status(user)},
         {:ok, scopes} <- validate_scopes(app, requested_scopes),
         {:ok, auth} <- Authorization.create_authorization(app, user, scopes) do
      {:ok, auth}
    end
  end

  # Note: intended to be a private function but opened for AccountController that logs in on signup
  @doc "If checks pass, creates authorization and token for given user, app and requested scopes."
  def login(%User{} = user, %App{} = app, requested_scopes) when is_list(requested_scopes) do
    with {:ok, auth} <- do_create_authorization(user, app, requested_scopes),
         {:mfa_required, _, _, false} <- {:mfa_required, user, auth, MFA.require?(user)},
         {:ok, token} <- Token.exchange_token(app, auth) do
      {:ok, token}
    end
  end

  defp redirect_uri(%Plug.Conn{}, redirect_uri), do: redirect_uri

  defp get_session_registration_id(%Plug.Conn{} = conn), do: get_session(conn, :registration_id)

  defp put_session_registration_id(%Plug.Conn{} = conn, registration_id),
    do: put_session(conn, :registration_id, registration_id)

  defp build_and_response_mfa_token(user, auth) do
    with {:ok, token} <- MFA.Token.create(user, auth) do
      MFAView.render("mfa_response.json", %{token: token, user: user})
    end
  end

  @spec validate_scopes(App.t(), map() | list()) ::
          {:ok, list()} | {:error, :missing_scopes | :unsupported_scopes}
  defp validate_scopes(%App{} = app, params) when is_map(params) do
    requested_scopes = Scopes.fetch_scopes(params, app.scopes)
    validate_scopes(app, requested_scopes)
  end

  defp validate_scopes(%App{} = app, requested_scopes) when is_list(requested_scopes) do
    Scopes.validate(requested_scopes, app.scopes)
  end

  def default_redirect_uri(%App{} = app) do
    app.redirect_uris
    |> String.split()
    |> Enum.at(0)
  end

  defp render_invalid_credentials_error(conn) do
    render_error(conn, :bad_request, "Invalid credentials")
  end
end
