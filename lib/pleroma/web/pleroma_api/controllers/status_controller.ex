# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.StatusController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  require Ecto.Query
  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated} when action == :quotes
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaStatusOperation

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
