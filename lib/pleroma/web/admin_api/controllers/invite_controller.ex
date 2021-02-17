# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InviteController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Config
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["admin:read:invites"]} when action == :index)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:invites"]} when action in [:create, :revoke, :email]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.InviteOperation

  @doc "Get list of created invites"
  def index(conn, _params) do
    invites = UserInviteToken.list_invites()

    render(conn, "index.json", invites: invites)
  end

  @doc "Create an account registration invite token"
  def create(%{body_params: params} = conn, _) do
    {:ok, invite} = UserInviteToken.create_invite(params)

    render(conn, "show.json", invite: invite)
  end

  @doc "Revokes invite by token"
  def revoke(%{body_params: %{token: token}} = conn, _) do
    with {:ok, invite} <- UserInviteToken.find_by_token(token),
         {:ok, updated_invite} = UserInviteToken.update_invite(invite, %{used: true}) do
      render(conn, "show.json", invite: updated_invite)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc "Sends registration invite via email"
  def email(%{assigns: %{user: user}, body_params: %{email: email} = params} = conn, _) do
    with {_, false} <- {:registrations_open, Config.get([:instance, :registrations_open])},
         {_, true} <- {:invites_enabled, Config.get([:instance, :invites_enabled])},
         {:ok, invite_token} <- UserInviteToken.create_invite(),
         {:ok, _} <-
           user
           |> Pleroma.Emails.UserEmail.user_invitation_email(
             invite_token,
             email,
             params[:name]
           )
           |> Pleroma.Emails.Mailer.deliver() do
      json_response(conn, :no_content, "")
    else
      {:registrations_open, _} ->
        {:error, "To send invites you need to set the `registrations_open` option to false."}

      {:invites_enabled, _} ->
        {:error, "To send invites you need to set the `invites_enabled` option to true."}

      {:error, error} ->
        {:error, error}
    end
  end
end
