# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [add_link_headers: 2, try_render: 3]

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

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    :assign_participant
    when action in [:accept_participation_request, :reject_participation_request]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"]}
    when action in [
           :create,
           :accept_participation_request,
           :reject_participation_request,
           :participate,
           :unparticipate
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"]}
    when action in [:participations, :participation_requests]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaEventOperation

  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    with {:ok, activity} <- CommonAPI.event(user, params) do
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

  def participations(%{assigns: %{user: user}} = conn, %{id: activity_id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         %Object{data: %{"participations" => participations}} <-
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
        %{assigns: %{user: %{ap_id: user_ap_id} = for_user}} = conn,
        %{id: activity_id} = params
      ) do
    with %Activity{object: %Object{data: %{"id" => ap_id, "actor" => ^user_ap_id}}} <-
           Activity.get_by_id_with_object(activity_id) do
      params =
        params
        |> Map.put(:type, "Join")
        |> Map.put(:object, ap_id)
        |> Map.put(:state, "pending")

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
    end
  end

  def participate(%{assigns: %{user: user}, body_params: params} = conn, %{id: event_id}) do
    with {:ok, _} <- CommonAPI.join(user, event_id, params),
         %Activity{} = activity <- Activity.get_by_id(event_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    end
  end

  def unparticipate(%{assigns: %{user: user}} = conn, %{id: event_id}) do
    with {:ok, _} <- CommonAPI.leave(user, event_id),
         %Activity{} = activity <- Activity.get_by_id(event_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    end
  end

  def accept_participation_request(
        %{assigns: %{user: for_user, participant: participant}} = conn,
        %{id: event_id}
      ) do
    with %Activity{data: %{"object" => ap_id}} <- Activity.get_by_id(event_id),
         {:ok, _} <- CommonAPI.accept_join_request(for_user, participant, ap_id),
         %Activity{} = activity <- Activity.get_by_id(event_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: for_user, as: :activity)
    end
  end

  def reject_participation_request(
        %{assigns: %{user: for_user, participant: participant}} = conn,
        %{id: event_id}
      ) do
    with %Activity{data: %{"object" => ap_id}} <- Activity.get_by_id(event_id),
         {:ok, _} <- CommonAPI.reject_join_request(for_user, participant, ap_id),
         %Activity{} = activity <- Activity.get_by_id(event_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: for_user, as: :activity)
    end
  end

  defp assign_participant(%{params: %{participant_id: id}} = conn, _) do
    case User.get_cached_by_id(id) do
      %User{} = participant -> assign(conn, :participant, participant)
      nil -> Pleroma.Web.MastodonAPI.FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end
end
