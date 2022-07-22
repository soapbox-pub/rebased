# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [try_render: 3]

  alias Pleroma.Activity
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.CommonAPI

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"]}
    when action in [:create, :participate]
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

  def participations(conn, %{"id" => activity_id}) do
  end

  def participation_requests(conn, %{"id" => activity_id}) do
    %Activity{object: %Object{data: %{"id" => ap_id}}} = activity <-
      Activity.get_by_id_with_object(activity_id)

    params =
      params
      |> Map.put(:type, "Join")
      |> Map.put(:object, ap_id)
      |> Map.put(:state, "pending")

    activities =
      recipients
      |> ActivityPub.fetch_activities(params)
      |> Enum.reverse()


  end

  def participate(%{assigns: %{user: user}} = conn, %{"id" => activity_id}) do
    with {:ok, _} <- CommonAPI.join(user, activity_id),
         %Activity{} = activity <- Activity.get_by_id(activity_id) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    end
  end
end
