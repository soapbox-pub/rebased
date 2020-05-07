# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.MFAController do
  @moduledoc """
  The model represents api to use Multi Factor authentications.
  """

  use Pleroma.Web, :controller

  alias Pleroma.MFA
  alias Pleroma.Web.Auth.TOTPAuthenticator
  alias Pleroma.Web.OAuth.MFAView, as: View
  alias Pleroma.Web.OAuth.OAuthController
  alias Pleroma.Web.OAuth.Token

  plug(:fetch_session when action in [:show, :verify])
  plug(:fetch_flash when action in [:show, :verify])

  @doc """
  Display form to input mfa code or recovery code.
  """
  def show(conn, %{"mfa_token" => mfa_token} = params) do
    template = Map.get(params, "challenge_type", "totp")

    conn
    |> put_view(View)
    |> render("#{template}.html", %{
      mfa_token: mfa_token,
      redirect_uri: params["redirect_uri"],
      state: params["state"]
    })
  end

  @doc """
  Verification code and continue authorization.
  """
  def verify(conn, %{"mfa" => %{"mfa_token" => mfa_token} = mfa_params} = _) do
    with {:ok, %{user: user, authorization: auth}} <- MFA.Token.validate(mfa_token),
         {:ok, _} <- validates_challenge(user, mfa_params) do
      conn
      |> OAuthController.after_create_authorization(auth, %{
        "authorization" => %{
          "redirect_uri" => mfa_params["redirect_uri"],
          "state" => mfa_params["state"]
        }
      })
    else
      _ ->
        conn
        |> put_flash(:error, "Two-factor authentication failed.")
        |> put_status(:unauthorized)
        |> show(mfa_params)
    end
  end

  @doc """
  Verification second step of MFA (or recovery) and returns access token.

  ## Endpoint
  POST /oauth/mfa/challenge

  params:
  `client_id`
  `client_secret`
  `mfa_token` - access token to check second step of mfa
  `challenge_type` - 'totp' or 'recovery'
  `code`

  """
  def challenge(conn, %{"mfa_token" => mfa_token} = params) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         {:ok, %{user: user, authorization: auth}} <- MFA.Token.validate(mfa_token),
         {:ok, _} <- validates_challenge(user, params),
         {:ok, token} <- Token.exchange_token(app, auth) do
      json(conn, Token.Response.build(user, token))
    else
      _error ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid code"})
    end
  end

  # Verify TOTP Code
  defp validates_challenge(user, %{"challenge_type" => "totp", "code" => code} = _) do
    TOTPAuthenticator.verify(code, user)
  end

  # Verify Recovery Code
  defp validates_challenge(user, %{"challenge_type" => "recovery", "code" => code} = _) do
    TOTPAuthenticator.verify_recovery_code(user, code)
  end

  defp validates_challenge(_, _), do: {:error, :unsupported_challenge_type}
end
