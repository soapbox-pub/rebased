# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [json_response: 3, add_link_headers: 2, assign_account_by_id: 2]

  alias Ecto.Changeset
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Plugs.RateLimiter
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  require Pleroma.Constants

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]} when action in [:subscribe, :unsubscribe]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]}
    # Note: the following actions are not permission-secured in Mastodon:
    when action in [
           :update_avatar,
           :update_banner,
           :update_background
         ]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:favourites"]} when action == :favourites)

  # An extra safety measure for possible actions not guarded by OAuth permissions specification
  plug(
    Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug
    when action != :confirmation_resend
  )

  plug(RateLimiter, :account_confirmation_resend when action == :confirmation_resend)
  plug(:assign_account_by_id when action in [:favourites, :subscribe, :unsubscribe])
  plug(:put_view, Pleroma.Web.MastodonAPI.AccountView)

  @doc "POST /api/v1/pleroma/accounts/confirmation_resend"
  def confirmation_resend(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    with %User{} = user <- User.get_by_nickname_or_email(nickname_or_email),
         {:ok, _} <- User.try_send_confirmation_email(user) do
      json_response(conn, :no_content, "")
    end
  end

  @doc "PATCH /api/v1/pleroma/accounts/update_avatar"
  def update_avatar(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    {:ok, user} =
      user
      |> Changeset.change(%{avatar: nil})
      |> User.update_and_set_cache()

    CommonAPI.update(user)

    json(conn, %{url: nil})
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, %{data: data}} = ActivityPub.upload(params, type: :avatar)
    {:ok, user} = user |> Changeset.change(%{avatar: data}) |> User.update_and_set_cache()
    %{"url" => [%{"href" => href} | _]} = data

    CommonAPI.update(user)

    json(conn, %{url: href})
  end

  @doc "PATCH /api/v1/pleroma/accounts/update_banner"
  def update_banner(%{assigns: %{user: user}} = conn, %{"banner" => ""}) do
    with {:ok, user} <- User.update_banner(user, %{}) do
      CommonAPI.update(user)
      json(conn, %{url: nil})
    end
  end

  def update_banner(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(%{"img" => params["banner"]}, type: :banner),
         {:ok, user} <- User.update_banner(user, object.data) do
      CommonAPI.update(user)
      %{"url" => [%{"href" => href} | _]} = object.data

      json(conn, %{url: href})
    end
  end

  @doc "PATCH /api/v1/pleroma/accounts/update_background"
  def update_background(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    with {:ok, _user} <- User.update_background(user, %{}) do
      json(conn, %{url: nil})
    end
  end

  def update_background(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(params, type: :background),
         {:ok, _user} <- User.update_background(user, object.data) do
      %{"url" => [%{"href" => href} | _]} = object.data

      json(conn, %{url: href})
    end
  end

  @doc "GET /api/v1/pleroma/accounts/:id/favourites"
  def favourites(%{assigns: %{account: %{hide_favorites: true}}} = conn, _params) do
    render_error(conn, :forbidden, "Can't get favorites")
  end

  def favourites(%{assigns: %{user: for_user, account: user}} = conn, params) do
    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("favorited_by", user.ap_id)
      |> Map.put("blocking_user", for_user)

    recipients =
      if for_user do
        [Pleroma.Constants.as_public()] ++ [for_user.ap_id | for_user.following]
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
    |> render("index.json", activities: activities, for: for_user, as: :activity)
  end

  @doc "POST /api/v1/pleroma/accounts/:id/subscribe"
  def subscribe(%{assigns: %{user: user, account: subscription_target}} = conn, _params) do
    with {:ok, subscription_target} <- User.subscribe(user, subscription_target) do
      render(conn, "relationship.json", user: user, target: subscription_target)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/pleroma/accounts/:id/unsubscribe"
  def unsubscribe(%{assigns: %{user: user, account: subscription_target}} = conn, _params) do
    with {:ok, subscription_target} <- User.unsubscribe(user, subscription_target) do
      render(conn, "relationship.json", user: user, target: subscription_target)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end
end
