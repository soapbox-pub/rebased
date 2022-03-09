# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AnnouncementController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [
      json_response: 3
    ]

  alias Pleroma.Announcement
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  # MastodonAPI specs do not have oauth requirements for showing
  # announcements, but we have "private instance" options. When that
  # is set, require read:accounts scope, symmetric to write:accounts
  # for `mark_read`.
  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:accounts"]}
    when action in [:show, :index]
  )

  # Same as in MastodonAPI specs
  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["write:accounts"]}
    when action in [:mark_read]
  )

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AnnouncementOperation

  @doc "GET /api/v1/announcements"
  def index(%{assigns: %{user: user}} = conn, _params) do
    render(conn, "index.json", announcements: all_visible(), user: user)
  end

  def index(conn, _params) do
    render(conn, "index.json", announcements: all_visible(), user: nil)
  end

  defp all_visible do
    Announcement.list_all_visible()
  end

  @doc "POST /api/v1/announcements/:id/dismiss"
  def mark_read(%{assigns: %{user: user}} = conn, %{id: id} = _params) do
    with announcement when not is_nil(announcement) <- Announcement.get_by_id(id),
         {:ok, _} <- Announcement.mark_read_by(announcement, user) do
      json_response(conn, :ok, %{})
    else
      _ ->
        {:error, :not_found}
    end
  end

  @doc "GET /api/v1/announcements/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: id} = _params) do
    render_announcement_by_id(conn, id, user)
  end

  def show(conn, %{id: id} = _params) do
    render_announcement_by_id(conn, id)
  end

  def render_announcement_by_id(conn, id, user \\ nil) do
    with announcement when not is_nil(announcement) <- Announcement.get_by_id(id) do
      render(conn, "show.json", announcement: announcement, user: user)
    else
      _ ->
        {:error, :not_found}
    end
  end
end
