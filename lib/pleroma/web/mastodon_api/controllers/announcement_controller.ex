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

  # Mastodon docs say this only requires a user token, no scopes needed
  # As the op `|` requires at least one scope to be present, we use `&` here.
  plug(
    OAuthScopesPlug,
    %{scopes: [], op: :&}
    when action in [:index]
  )

  # Same as in MastodonAPI specs
  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]}
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
end
