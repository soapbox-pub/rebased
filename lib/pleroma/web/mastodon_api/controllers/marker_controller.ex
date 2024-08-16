# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"]}
    when action == :index
  )

  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action == :upsert)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.MarkerOperation

  # GET /api/v1/markers
  def index(%{assigns: %{user: user}} = conn, params) do
    markers = Pleroma.Marker.get_markers(user, params[:timeline])
    render(conn, "markers.json", %{markers: markers})
  end

  # POST /api/v1/markers
  def upsert(%{assigns: %{user: user}, body_params: params} = conn, _) do
    params = Map.new(params, fn {key, value} -> {to_string(key), value} end)

    with {:ok, _} <- mark_notifications_read(user, params),
         {:ok, result} <- Pleroma.Marker.upsert(user, params),
         markers <- Map.values(result) do
      render(conn, "markers.json", %{markers: markers})
    end
  end

  defp mark_notifications_read(user, %{"notifications" => %{last_read_id: last_read_id}}) do
    Pleroma.Notification.set_read_up_to(user, last_read_id)
  end

  defp mark_notifications_read(_, _), do: {:ok, :noop}
end
