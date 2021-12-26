# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.TimelineController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [add_link_headers: 2, add_link_headers: 3]

  alias Pleroma.Config
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(:skip_public_check when action in [:public, :hashtag])

  # TODO: Replace with a macro when there is a Phoenix release with the following commit in it:
  # https://github.com/phoenixframework/phoenix/commit/2e8c63c01fec4dde5467dbbbf9705ff9e780735e

  plug(RateLimiter, [name: :timeline, bucket_name: :direct_timeline] when action == :direct)
  plug(RateLimiter, [name: :timeline, bucket_name: :public_timeline] when action == :public)
  plug(RateLimiter, [name: :timeline, bucket_name: :home_timeline] when action == :home)
  plug(RateLimiter, [name: :timeline, bucket_name: :hashtag_timeline] when action == :hashtag)
  plug(RateLimiter, [name: :timeline, bucket_name: :list_timeline] when action == :list)

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action in [:home, :direct])
  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action == :list)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated}
    when action in [:public, :hashtag]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.TimelineOperation

  # GET /api/v1/timelines/home
  def home(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:blocking_user, user)
      |> Map.put(:muting_user, user)
      |> Map.put(:reply_filtering_user, user)
      |> Map.put(:announce_filtering_user, user)
      |> Map.put(:user, user)
      |> Map.put(:local_only, params[:local])
      |> Map.delete(:local)

    activities =
      [user.ap_id | User.following(user)]
      |> ActivityPub.fetch_activities(params)
      |> Enum.reverse()

    conn
    |> add_link_headers(activities)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity,
      with_muted: Map.get(params, :with_muted, false)
    )
  end

  # GET /api/v1/timelines/direct
  def direct(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put(:type, "Create")
      |> Map.put(:blocking_user, user)
      |> Map.put(:user, user)
      |> Map.put(:visibility, "direct")

    activities =
      [user.ap_id]
      |> ActivityPub.fetch_activities_query(params)
      |> Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(activities)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity
    )
  end

  defp restrict_unauthenticated?(true = _local_only) do
    Config.restrict_unauthenticated_access?(:timelines, :local)
  end

  defp restrict_unauthenticated?(_) do
    Config.restrict_unauthenticated_access?(:timelines, :federated)
  end

  # GET /api/v1/timelines/public
  def public(%{assigns: %{user: user}} = conn, params) do
    local_only = params[:local]

    if is_nil(user) and restrict_unauthenticated?(local_only) do
      fail_on_bad_auth(conn)
    else
      activities =
        params
        |> Map.put(:type, ["Create"])
        |> Map.put(:local_only, local_only)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:instance, params[:instance])
        |> ActivityPub.fetch_public_activities()

      conn
      |> add_link_headers(activities, %{"local" => local_only})
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    end
  end

  defp fail_on_bad_auth(conn) do
    render_error(conn, :unauthorized, "authorization required for timeline view")
  end

  defp hashtag_fetching(params, user, local_only) do
    # Note: not sanitizing tag options at this stage (may be mix-cased, have duplicates etc.)
    tags_any =
      [params[:tag], params[:any]]
      |> List.flatten()
      |> Enum.filter(& &1)

    tag_all = Map.get(params, :all, [])
    tag_reject = Map.get(params, :none, [])

    params
    |> Map.put(:type, "Create")
    |> Map.put(:local_only, local_only)
    |> Map.put(:blocking_user, user)
    |> Map.put(:muting_user, user)
    |> Map.put(:user, user)
    |> Map.put(:tag, tags_any)
    |> Map.put(:tag_all, tag_all)
    |> Map.put(:tag_reject, tag_reject)
    |> ActivityPub.fetch_public_activities()
  end

  # GET /api/v1/timelines/tag/:tag
  def hashtag(%{assigns: %{user: user}} = conn, params) do
    local_only = params[:local]

    if is_nil(user) and restrict_unauthenticated?(local_only) do
      fail_on_bad_auth(conn)
    else
      activities = hashtag_fetching(params, user, local_only)

      conn
      |> add_link_headers(activities, %{"local" => local_only})
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    end
  end

  # GET /api/v1/timelines/list/:list_id
  def list(%{assigns: %{user: user}} = conn, %{list_id: id} = params) do
    with %Pleroma.List{title: _title, following: following} <- Pleroma.List.get(id, user) do
      params =
        params
        |> Map.put(:type, "Create")
        |> Map.put(:blocking_user, user)
        |> Map.put(:user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:local_only, params[:local])

      # we must filter the following list for the user to avoid leaking statuses the user
      # does not actually have permission to see (for more info, peruse security issue #270).

      user_following = User.following(user)

      activities =
        following
        |> Enum.filter(fn x -> x in user_following end)
        |> ActivityPub.fetch_activities_bounded(following, params)
        |> Enum.reverse()

      conn
      |> add_link_headers(activities)
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      _e -> render_error(conn, :forbidden, "Error.")
    end
  end
end
