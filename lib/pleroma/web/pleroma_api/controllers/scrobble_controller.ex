# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ScrobbleController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2, fetch_integer_param: 2]

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :user_scrobbles)
  plug(OAuthScopesPlug, %{scopes: ["write"]} when action != :user_scrobbles)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  def new_scrobble(%{assigns: %{user: user}} = conn, %{"title" => _} = params) do
    params =
      if !params["length"] do
        params
      else
        params
        |> Map.put("length", fetch_integer_param(params, "length"))
      end

    with {:ok, activity} <- CommonAPI.listen(user, params) do
      conn
      |> put_view(StatusView)
      |> render("listen.json", %{activity: activity, for: user})
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def user_scrobbles(%{assigns: %{user: reading_user}} = conn, params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(params["id"], for: reading_user) do
      params = Map.put(params, "type", ["Listen"])

      activities = ActivityPub.fetch_user_abstract_activities(user, reading_user, params)

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("listens.json", %{
        activities: activities,
        for: reading_user,
        as: :activity
      })
    end
  end
end
