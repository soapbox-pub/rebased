# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Conversation.Participation
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Repo

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action == :index)
  plug(OAuthScopesPlug, %{scopes: ["write:conversations"]} when action == :read)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "GET /api/v1/conversations"
  def index(%{assigns: %{user: user}} = conn, params) do
    participations = Participation.for_user_with_last_activity_id(user, params)

    conn
    |> add_link_headers(participations)
    |> render("participations.json", participations: participations, for: user)
  end

  @doc "POST /api/v1/conversations/:id/read"
  def read(%{assigns: %{user: user}} = conn, %{"id" => participation_id}) do
    with %Participation{} = participation <-
           Repo.get_by(Participation, id: participation_id, user_id: user.id),
         {:ok, participation} <- Participation.mark_as_read(participation) do
      render(conn, "participation.json", participation: participation, for: user)
    end
  end
end
