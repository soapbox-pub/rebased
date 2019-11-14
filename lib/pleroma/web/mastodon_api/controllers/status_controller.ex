# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [try_render: 3, add_link_headers: 2]

  require Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Plugs.RateLimiter
  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.ScheduledActivityView

  @unauthenticated_access %{fallback: :proceed_unauthenticated, scopes: []}

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:statuses"]}
    when action in [
           :index,
           :show,
           :card,
           :context
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:statuses"]}
    when action in [
           :create,
           :delete,
           :reblog,
           :unreblog
         ]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:favourites"]} when action == :favourites)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:favourites"]} when action in [:favourite, :unfavourite]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:mutes"]} when action in [:mute_conversation, :unmute_conversation]
  )

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:accounts"]}
    when action in [:favourited_by, :reblogged_by]
  )

  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action in [:pin, :unpin])

  # Note: scope not present in Mastodon: read:bookmarks
  plug(OAuthScopesPlug, %{scopes: ["read:bookmarks"]} when action == :bookmarks)

  # Note: scope not present in Mastodon: write:bookmarks
  plug(
    OAuthScopesPlug,
    %{scopes: ["write:bookmarks"]} when action in [:bookmark, :unbookmark]
  )

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @rate_limited_status_actions ~w(reblog unreblog favourite unfavourite create delete)a

  plug(
    RateLimiter,
    [name: :status_id_action, bucket_name: "status_id_action:reblog_unreblog", params: ["id"]]
    when action in ~w(reblog unreblog)a
  )

  plug(
    RateLimiter,
    [name: :status_id_action, bucket_name: "status_id_action:fav_unfav", params: ["id"]]
    when action in ~w(favourite unfavourite)a
  )

  plug(RateLimiter, [name: :statuses_actions] when action in @rate_limited_status_actions)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc """
  GET `/api/v1/statuses?ids[]=1&ids[]=2`

  `ids` query param is required
  """
  def index(%{assigns: %{user: user}} = conn, %{"ids" => ids}) do
    limit = 100

    activities =
      ids
      |> Enum.take(limit)
      |> Activity.all_by_ids_with_object()
      |> Enum.filter(&Visibility.visible_for_user?(&1, user))

    render(conn, "index.json", activities: activities, for: user, as: :activity)
  end

  @doc """
  POST /api/v1/statuses

  Creates a scheduled status when `scheduled_at` param is present and it's far enough
  """
  def create(
        %{assigns: %{user: user}} = conn,
        %{"status" => _, "scheduled_at" => scheduled_at} = params
      ) do
    params = Map.put(params, "in_reply_to_status_id", params["in_reply_to_id"])

    if ScheduledActivity.far_enough?(scheduled_at) do
      with {:ok, scheduled_activity} <-
             ScheduledActivity.create(user, %{"params" => params, "scheduled_at" => scheduled_at}) do
        conn
        |> put_view(ScheduledActivityView)
        |> render("show.json", scheduled_activity: scheduled_activity)
      end
    else
      create(conn, Map.drop(params, ["scheduled_at"]))
    end
  end

  @doc """
  POST /api/v1/statuses

  Creates a regular status
  """
  def create(%{assigns: %{user: user}} = conn, %{"status" => _} = params) do
    params = Map.put(params, "in_reply_to_status_id", params["in_reply_to_id"])

    with {:ok, activity} <- CommonAPI.post(user, params) do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        as: :activity,
        with_direct_conversation_id: true
      )
    else
      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def create(%{assigns: %{user: _user}} = conn, %{"media_ids" => _} = params) do
    create(conn, Map.put(params, "status", ""))
  end

  @doc "GET /api/v1/statuses/:id"
  def show(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true
      )
    end
  end

  @doc "DELETE /api/v1/statuses/:id"
  def delete(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      json(conn, %{})
    else
      _e -> render_error(conn, :forbidden, "Can't delete this post")
    end
  end

  @doc "POST /api/v1/statuses/:id/reblog"
  def reblog(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id} = params) do
    with {:ok, announce, _activity} <- CommonAPI.repeat(ap_id_or_id, user, params),
         %Activity{} = announce <- Activity.normalize(announce.data) do
      try_render(conn, "show.json", %{activity: announce, for: user, as: :activity})
    end
  end

  @doc "POST /api/v1/statuses/:id/unreblog"
  def unreblog(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _unannounce, %{data: %{"id" => id}}} <- CommonAPI.unrepeat(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id_with_object(id) do
      try_render(conn, "show.json", %{activity: activity, for: user, as: :activity})
    end
  end

  @doc "POST /api/v1/statuses/:id/favourite"
  def favourite(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _fav, %{data: %{"id" => id}}} <- CommonAPI.favorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/unfavourite"
  def unfavourite(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _, _, %{data: %{"id" => id}}} <- CommonAPI.unfavorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/pin"
  def pin(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, activity} <- CommonAPI.pin(ap_id_or_id, user) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/unpin"
  def unpin(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, activity} <- CommonAPI.unpin(ap_id_or_id, user) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/bookmark"
  def bookmark(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         %User{} = user <- User.get_cached_by_nickname(user.nickname),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _bookmark} <- Bookmark.create(user.id, activity.id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/unbookmark"
  def unbookmark(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         %User{} = user <- User.get_cached_by_nickname(user.nickname),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _bookmark} <- Bookmark.destroy(user.id, activity.id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/mute"
  def mute_conversation(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, activity} <- CommonAPI.add_mute(user, activity) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/unmute"
  def unmute_conversation(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, activity} <- CommonAPI.remove_mute(user, activity) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "GET /api/v1/statuses/:id/card"
  @deprecated "https://github.com/tootsuite/mastodon/pull/11213"
  def card(%{assigns: %{user: user}} = conn, %{"id" => status_id}) do
    with %Activity{} = activity <- Activity.get_by_id(status_id),
         true <- Visibility.visible_for_user?(activity, user) do
      data = Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
      render(conn, "card.json", data)
    else
      _ -> render_error(conn, :not_found, "Record not found")
    end
  end

  @doc "GET /api/v1/statuses/:id/favourited_by"
  def favourited_by(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         %Object{data: %{"likes" => likes}} <- Object.normalize(activity) do
      users =
        User
        |> Ecto.Query.where([u], u.ap_id in ^likes)
        |> Repo.all()
        |> Enum.filter(&(not User.blocks?(user, &1)))

      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    else
      {:visible, false} -> {:error, :not_found}
      _ -> json(conn, [])
    end
  end

  @doc "GET /api/v1/statuses/:id/reblogged_by"
  def reblogged_by(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         %Object{data: %{"announcements" => announces, "id" => ap_id}} <-
           Object.normalize(activity) do
      announces =
        "Announce"
        |> Activity.Queries.by_type()
        |> Ecto.Query.where([a], a.actor in ^announces)
        # this is to use the index
        |> Activity.Queries.by_object_id(ap_id)
        |> Repo.all()
        |> Enum.filter(&Visibility.visible_for_user?(&1, user))
        |> Enum.map(& &1.actor)
        |> Enum.uniq()

      users =
        User
        |> Ecto.Query.where([u], u.ap_id in ^announces)
        |> Repo.all()
        |> Enum.filter(&(not User.blocks?(user, &1)))

      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    else
      {:visible, false} -> {:error, :not_found}
      _ -> json(conn, [])
    end
  end

  @doc "GET /api/v1/statuses/:id/context"
  def context(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id) do
      activities =
        ActivityPub.fetch_activities_for_context(activity.data["context"], %{
          "blocking_user" => user,
          "user" => user,
          "exclude_id" => activity.id
        })

      render(conn, "context.json", activity: activity, activities: activities, user: user)
    end
  end

  @doc "GET /api/v1/favourites"
  def favourites(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("favorited_by", user.ap_id)
      |> Map.put("blocking_user", user)

    activities =
      ActivityPub.fetch_activities([], params)
      |> Enum.reverse()

    conn
    |> add_link_headers(activities)
    |> render("index.json", activities: activities, for: user, as: :activity)
  end

  @doc "GET /api/v1/bookmarks"
  def bookmarks(%{assigns: %{user: user}} = conn, params) do
    user = User.get_cached_by_id(user.id)

    bookmarks =
      user.id
      |> Bookmark.for_user_query()
      |> Pleroma.Pagination.fetch_paginated(params)

    activities =
      bookmarks
      |> Enum.map(fn b -> Map.put(b.activity, :bookmark, Map.delete(b, :activity)) end)

    conn
    |> add_link_headers(bookmarks)
    |> render("index.json", %{activities: activities, for: user, as: :activity})
  end
end
