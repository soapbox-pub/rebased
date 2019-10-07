# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.TimelineController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [add_link_headers: 2, add_link_headers: 3, truthy_param?: 1]

  alias Pleroma.Pagination
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.ActivityPub.ActivityPub

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action in [:home, :direct])
  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action == :list)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  plug(:put_view, Pleroma.Web.MastodonAPI.StatusView)

  # GET /api/v1/timelines/home
  def home(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> Map.put("user", user)

    recipients = [user.ap_id | user.following]

    activities =
      recipients
      |> ActivityPub.fetch_activities(params)
      |> Enum.reverse()

    conn
    |> add_link_headers(activities)
    |> render("index.json", activities: activities, for: user, as: :activity)
  end

  # GET /api/v1/timelines/direct
  def direct(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("blocking_user", user)
      |> Map.put("user", user)
      |> Map.put(:visibility, "direct")

    activities =
      [user.ap_id]
      |> ActivityPub.fetch_activities_query(params)
      |> Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(activities)
    |> render("index.json", activities: activities, for: user, as: :activity)
  end

  # GET /api/v1/timelines/public
  def public(%{assigns: %{user: user}} = conn, params) do
    local_only = truthy_param?(params["local"])

    activities =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("local_only", local_only)
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> ActivityPub.fetch_public_activities()
      |> Enum.reverse()

    conn
    |> add_link_headers(activities, %{"local" => local_only})
    |> render("index.json", activities: activities, for: user, as: :activity)
  end

  # GET /api/v1/timelines/tag/:tag
  def hashtag(%{assigns: %{user: user}} = conn, params) do
    local_only = truthy_param?(params["local"])

    tags =
      [params["tag"], params["any"]]
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.filter(& &1)
      |> Enum.map(&String.downcase(&1))

    tag_all =
      params
      |> Map.get("all", [])
      |> Enum.map(&String.downcase(&1))

    tag_reject =
      params
      |> Map.get("none", [])
      |> Enum.map(&String.downcase(&1))

    activities =
      params
      |> Map.put("type", "Create")
      |> Map.put("local_only", local_only)
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> Map.put("user", user)
      |> Map.put("tag", tags)
      |> Map.put("tag_all", tag_all)
      |> Map.put("tag_reject", tag_reject)
      |> ActivityPub.fetch_public_activities()
      |> Enum.reverse()

    conn
    |> add_link_headers(activities, %{"local" => local_only})
    |> render("index.json", activities: activities, for: user, as: :activity)
  end

  # GET /api/v1/timelines/list/:list_id
  def list(%{assigns: %{user: user}} = conn, %{"list_id" => id} = params) do
    with %Pleroma.List{title: _title, following: following} <- Pleroma.List.get(id, user) do
      params =
        params
        |> Map.put("type", "Create")
        |> Map.put("blocking_user", user)
        |> Map.put("user", user)
        |> Map.put("muting_user", user)

      # we must filter the following list for the user to avoid leaking statuses the user
      # does not actually have permission to see (for more info, peruse security issue #270).
      activities =
        following
        |> Enum.filter(fn x -> x in user.following end)
        |> ActivityPub.fetch_activities_bounded(following, params)
        |> Enum.reverse()

      render(conn, "index.json", activities: activities, for: user, as: :activity)
    else
      _e -> render_error(conn, :forbidden, "Error.")
    end
  end
end
