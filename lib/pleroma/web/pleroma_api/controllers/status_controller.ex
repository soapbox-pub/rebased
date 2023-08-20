# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.StatusController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2, try_render: 3]

  require Ecto.Query
  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:notifications"]}
    when action in [:subscribe_conversation, :unsubscribe_conversation]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated} when action == :quotes
  )

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaStatusOperation

  @doc "POST /api/v1/pleroma/statuses/:id/subscribe"
  def subscribe_conversation(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, activity} <- CommonAPI.add_subscription(user, activity) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/pleroma/statuses/:id/unsubscribe"
  def unsubscribe_conversation(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, activity} <- CommonAPI.remove_subscription(user, activity) do
      conn
      |> put_view(StatusView)
      |> try_render("show.json", activity: activity, for: user, as: :activity)
         end

  @doc "GET /api/v1/pleroma/statuses/:id/quotes"
  def quotes(%{assigns: %{user: user}} = conn, %{id: id} = params) do
    with %Activity{object: object} = activity <- Activity.get_by_id_with_object(id),
         true <- Visibility.visible_for_user?(activity, user) do
      params =
        params
        |> Map.put(:type, "Create")
        |> Map.put(:blocking_user, user)
        |> Map.put(:quote_url, object.data["id"])

      recipients =
        if user do
          [Pleroma.Constants.as_public()] ++ [user.ap_id | User.following(user)]
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
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity
      )
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_found}
    end
  end
end
