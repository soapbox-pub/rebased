# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [json_response: 3, add_link_headers: 2, assign_account_by_id: 2]

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  require Pleroma.Constants

  plug(
    Majic.Plug,
    [pool: Pleroma.MajicPool] when action in [:update_avatar, :update_background, :update_banner]
  )

  plug(
    OpenApiSpex.Plug.PutApiSpec,
    [module: Pleroma.Web.ApiSpec] when action == :confirmation_resend
  )

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:skip_auth when action == :confirmation_resend)

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]} when action in [:subscribe, :unsubscribe]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:favourites"], fallback: :proceed_unauthenticated} when action == :favourites
  )

  plug(RateLimiter, [name: :account_confirmation_resend] when action == :confirmation_resend)

  plug(:assign_account_by_id when action in [:favourites, :subscribe, :unsubscribe])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaAccountOperation

  @doc "POST /api/v1/pleroma/accounts/confirmation_resend"
  def confirmation_resend(conn, params) do
    nickname_or_email = params[:email] || params[:nickname]

    with %User{} = user <- User.get_by_nickname_or_email(nickname_or_email),
         {:ok, _} <- User.maybe_send_confirmation_email(user) do
      json_response(conn, :no_content, "")
    end
  end

  @doc "GET /api/v1/pleroma/accounts/:id/favourites"
  def favourites(%{assigns: %{account: %{hide_favorites: true}}} = conn, _params) do
    render_error(conn, :forbidden, "Can't get favorites")
  end

  def favourites(%{assigns: %{user: for_user, account: user}} = conn, params) do
    params =
      params
      |> Map.put(:type, "Create")
      |> Map.put(:favorited_by, user.ap_id)
      |> Map.put(:blocking_user, for_user)

    recipients =
      if for_user do
        [Pleroma.Constants.as_public()] ++ [for_user.ap_id | User.following(for_user)]
      else
        [Pleroma.Constants.as_public()]
      end

    activities =
      recipients
      |> ActivityPub.fetch_activities(params)
      |> Enum.reverse()

    conn
    |> add_link_headers(activities)
    |> put_view(StatusView)
    |> render("index.json",
      activities: activities,
      for: for_user,
      as: :activity
    )
  end

  @doc "POST /api/v1/pleroma/accounts/:id/subscribe"
  def subscribe(%{assigns: %{user: user, account: subscription_target}} = conn, _params) do
    with {:ok, _subscription} <- User.subscribe(user, subscription_target) do
      render(conn, "relationship.json", user: user, target: subscription_target)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/pleroma/accounts/:id/unsubscribe"
  def unsubscribe(%{assigns: %{user: user, account: subscription_target}} = conn, _params) do
    with {:ok, _subscription} <- User.unsubscribe(user, subscription_target) do
      render(conn, "relationship.json", user: user, target: subscription_target)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end
end
