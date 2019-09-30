# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2, truthy_param?: 1]

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.MastodonAPI.ListView
  alias Pleroma.Plugs.RateLimiter

  require Pleroma.Constants

  @relations ~w(follow unfollow)a

  plug(RateLimiter, {:relations_id_action, params: ["id", "uri"]} when action in @relations)
  plug(RateLimiter, :relations_actions when action in @relations)
  plug(:assign_account when action not in [:show, :statuses, :follows])

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc "GET /api/v1/accounts/:id"
  def show(%{assigns: %{user: for_user}} = conn, %{"id" => nickname_or_id}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname_or_id, for: for_user),
         true <- User.auth_active?(user) || user.id == for_user.id || User.superuser?(for_user) do
      render(conn, "show.json", user: user, for: for_user)
    else
      _e -> render_error(conn, :not_found, "Can't find user")
    end
  end

  @doc "GET /api/v1/accounts/:id/statuses"
  def statuses(%{assigns: %{user: reading_user}} = conn, params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(params["id"], for: reading_user) do
      params = Map.put(params, "tag", params["tagged"])
      activities = ActivityPub.fetch_user_activities(user, reading_user, params)

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json", activities: activities, for: reading_user, as: :activity)
    end
  end

  @doc "GET /api/v1/accounts/:id/followers"
  def followers(%{assigns: %{user: for_user, account: user}} = conn, params) do
    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_followers(user, params)
        user.info.hide_followers -> []
        true -> MastodonAPI.get_followers(user, params)
      end

    conn
    |> add_link_headers(followers)
    |> render("index.json", for: for_user, users: followers, as: :user)
  end

  @doc "GET /api/v1/accounts/:id/following"
  def following(%{assigns: %{user: for_user, account: user}} = conn, params) do
    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_friends(user, params)
        user.info.hide_follows -> []
        true -> MastodonAPI.get_friends(user, params)
      end

    conn
    |> add_link_headers(followers)
    |> render("index.json", for: for_user, users: followers, as: :user)
  end

  @doc "GET /api/v1/accounts/:id/lists"
  def lists(%{assigns: %{user: user, account: account}} = conn, _params) do
    lists = Pleroma.List.get_lists_account_belongs(user, account)

    conn
    |> put_view(ListView)
    |> render("index.json", lists: lists)
  end

  @doc "GET /api/v1/pleroma/accounts/:id/favourites"
  def favourites(%{assigns: %{account: %{info: %{hide_favorites: true}}}} = conn, _params) do
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
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/pleroma/accounts/:id/unsubscribe"
  def unsubscribe(%{assigns: %{user: user, account: subscription_target}} = conn, _params) do
    with {:ok, subscription_target} <- User.unsubscribe(user, subscription_target) do
      render(conn, "relationship.json", user: user, target: subscription_target)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/follow"
  def follow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, :not_found}
  end

  def follow(%{assigns: %{user: follower, account: followed}} = conn, _params) do
    with {:ok, follower} <- MastodonAPI.follow(follower, followed, conn.params) do
      render(conn, "relationship.json", user: follower, target: followed)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/pleroma/:id/unfollow"
  def unfollow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, :not_found}
  end

  def unfollow(%{assigns: %{user: follower, account: followed}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.unfollow(follower, followed) do
      render(conn, "relationship.json", user: follower, target: followed)
    end
  end

  @doc "POST /api/v1/accounts/:id/mute"
  def mute(%{assigns: %{user: muter, account: muted}} = conn, params) do
    notifications? = params |> Map.get("notifications", true) |> truthy_param?()

    with {:ok, muter} <- User.mute(muter, muted, notifications?) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unmute"
  def unmute(%{assigns: %{user: muter, account: muted}} = conn, _params) do
    with {:ok, muter} <- User.unmute(muter, muted) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/block"
  def block(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, blocker} <- User.block(blocker, blocked),
         {:ok, _activity} <- ActivityPub.block(blocker, blocked) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unblock"
  def unblock(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, blocker} <- User.unblock(blocker, blocked),
         {:ok, _activity} <- ActivityPub.unblock(blocker, blocked) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  defp assign_account(%{params: %{"id" => id}} = conn, _) do
    case User.get_cached_by_id(id) do
      %User{} = account -> assign(conn, :account, account)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end
end
