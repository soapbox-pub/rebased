# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [add_link_headers: 2, json_response: 3, try_render: 3]

  require Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.PleromaAPI.EventView
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    :assign_participant
    when action in [:authorize_participation_request, :reject_participation_request]
  )

  plug(
    :assign_event_activity
    when action in [
           :participations,
           :participation_requests,
           :authorize_participation_request,
           :reject_participation_request,
           :join,
           :leave,
           :export_ics
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"]}
    when action in [
           :create,
           :update,
           :authorize_participation_request,
           :reject_participation_request,
           :join,
           :leave
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"]}
    when action in [:participations, :participation_requests, :joined_events]
  )

  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:statuses"]}
    when action in [:export_ics]
  )

  @rate_limited_event_actions ~w(create update join leave)a

  plug(
    RateLimiter,
    [name: :status_id_action, bucket_name: "status_id_action:join_leave", params: [:id]]
    when action in ~w(join leave)a
  )

  plug(RateLimiter, [name: :events_actions] when action in @rate_limited_event_actions)

  plug(Pleroma.Web.Plugs.SetApplicationPlug, [] when action in [:create, :update])

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaEventOperation

  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    params =
      params
      |> Map.put(:status, Map.get(params, :status, ""))

    with location <- get_location(params),
         {:ok, activity} <- CommonAPI.event(user, params, location) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json",
        activity: activity,
        for: user,
        as: :activity
      )
    else
      {:error, {:reject, message}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  @doc "PUT /api/v1/pleroma/events/:id"
  def update(%{assigns: %{user: user}, body_params: body_params} = conn, %{id: id} = params) do
    with {_, %Activity{}} = {_, activity} <- {:activity, Activity.get_by_id_with_object(id)},
         {_, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         {_, true} <- {:is_create, activity.data["type"] == "Create"},
         actor <- Activity.user_actor(activity),
         {_, true} <- {:own_status, actor.id == user.id},
         changes <- body_params |> Map.put(:generator, conn.assigns.application),
         location <- get_location(body_params),
         {_, {:ok, _update_activity}} <-
           {:pipeline, CommonAPI.update_event(user, activity, changes, location)},
         {_, %Activity{}} = {_, activity} <- {:refetched, Activity.get_by_id_with_object(id)} do
      conn
      |> put_view(StatusView)
      |> try_render("show.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      {:own_status, _} -> {:error, :forbidden}
      {:pipeline, _} -> {:error, :internal_server_error}
      _ -> {:error, :not_found}
    end
  end

  defp get_location(%{location_id: location_id}) when is_binary(location_id) do
    result = Geospatial.Service.service().get_by_id(location_id)

    result |> List.first()
  end

  defp get_location(_), do: nil

  def participations(%{assigns: %{user: user, event_activity: activity}} = conn, _) do
    with %Object{data: %{"participations" => participations}} <-
           Object.normalize(activity, fetch: false) do
      users =
        User
        |> Ecto.Query.where([u], u.ap_id in ^participations)
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

  def participation_requests(
        %{assigns: %{user: %{ap_id: user_ap_id} = for_user, event_activity: activity}} = conn,
        params
      ) do
    case activity do
      %Activity{actor: ^user_ap_id, data: %{"object" => ap_id}} ->
        params =
          Map.merge(params, %{
            type: "Join",
            object: ap_id,
            state: "pending",
            skip_preload: true
          })

        activities =
          []
          |> ActivityPub.fetch_activities_query(params)
          |> Pagination.fetch_paginated(params)

        conn
        |> add_link_headers(activities)
        |> put_view(EventView)
        |> render("participation_requests.json",
          activities: activities,
          for: for_user,
          as: :activity
        )

      %Activity{} ->
        render_error(conn, :forbidden, "Can't get participation requests")

      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  def join(%{assigns: %{user: %{ap_id: actor}, event_activity: %{actor: actor}}} = conn, _) do
    render_error(conn, :bad_request, "Can't join your own event")
  end

  def join(
        %{assigns: %{user: user, event_activity: activity}, body_params: params} = conn,
        _
      ) do
    with {:ok, _} <- CommonAPI.join(user, activity.id, params) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    end
  end

  def leave(
        %{assigns: %{user: %{ap_id: actor}, event_activity: %{actor: actor}}} = conn,
        _
      ) do
    render_error(conn, :bad_request, "Can't leave your own event")
  end

  def leave(%{assigns: %{user: user, event_activity: activity}} = conn, _) do
    with {:ok, _} <- CommonAPI.leave(user, activity.id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    else
      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  def authorize_participation_request(
        %{
          assigns: %{
            user: for_user,
            participant: participant,
            event_activity: %Activity{data: %{"object" => ap_id}} = activity
          }
        } = conn,
        _
      ) do
    with actor <- Activity.user_actor(activity),
         {_, true} <- {:own_event, actor.id == for_user.id},
         {:ok, _} <- CommonAPI.accept_join_request(for_user, participant, ap_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: for_user, as: :activity)
    else
      {:own_event, _} -> {:error, :forbidden}
    end
  end

  def reject_participation_request(
        %{
          assigns: %{
            user: for_user,
            participant: participant,
            event_activity: %Activity{data: %{"object" => ap_id}} = activity
          }
        } = conn,
        _
      ) do
    with actor <- Activity.user_actor(activity),
         {_, true} <- {:own_event, actor.id == for_user.id},
         {:ok, _} <- CommonAPI.reject_join_request(for_user, participant, ap_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: for_user, as: :activity)
    else
      {:own_event, _} -> {:error, :forbidden}
    end
  end

  def export_ics(%{assigns: %{event_activity: activity}} = conn, _) do
    render(conn, "show.ics", activity: activity)
  end

  defp assign_participant(%{params: %{participant_id: id}} = conn, _) do
    case User.get_cached_by_id(id) do
      %User{} = participant -> assign(conn, :participant, participant)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end

  defp assign_event_activity(%{assigns: %{user: user}, params: %{id: event_id}} = conn, _) do
    with %Activity{} = activity <- Activity.get_by_id(event_id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)} do
      assign(conn, :event_activity, activity)
    else
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end

  def joined_events(%{assigns: %{user: %User{} = user}} = conn, params) do
    activities = ActivityPub.fetch_joined_events(user, params)

    conn
    |> add_link_headers(activities)
    |> put_view(StatusView)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity
    )
  end
end
