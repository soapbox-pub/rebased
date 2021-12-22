# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ConversationController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Conversation.Participation
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action in [:show, :statuses])

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:conversations"]} when action in [:update, :mark_as_read]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaConversationOperation

  def show(%{assigns: %{user: %{id: user_id} = user}} = conn, %{id: participation_id}) do
    with %Participation{user_id: ^user_id} = participation <- Participation.get(participation_id) do
      render(conn, "participation.json", participation: participation, for: user)
    else
      _error ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "Unknown conversation id"})
    end
  end

  def statuses(
        %{assigns: %{user: %{id: user_id} = user}} = conn,
        %{id: participation_id} = params
      ) do
    with %Participation{user_id: ^user_id} = participation <-
           Participation.get(participation_id, preload: [:conversation]) do
      params =
        params
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)

      activities =
        participation.conversation.ap_id
        |> ActivityPub.fetch_activities_for_context_query(params)
        |> Pleroma.Pagination.fetch_paginated(Map.put(params, :total, false))
        |> Enum.reverse()

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json", activities: activities, for: user, as: :activity)
    else
      _error ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "Unknown conversation id"})
    end
  end

  def update(
        %{assigns: %{user: %{id: user_id} = user}} = conn,
        %{id: participation_id, recipients: recipients}
      ) do
    with %Participation{user_id: ^user_id} = participation <- Participation.get(participation_id),
         {:ok, participation} <- Participation.set_recipients(participation, recipients) do
      render(conn, "participation.json", participation: participation, for: user)
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})

      _error ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "Unknown conversation id"})
    end
  end

  def mark_as_read(%{assigns: %{user: user}} = conn, _params) do
    with {:ok, _, participations} <- Participation.mark_all_as_read(user) do
      conn
      |> add_link_headers(participations)
      |> render("participations.json", participations: participations, for: user)
    end
  end
end
