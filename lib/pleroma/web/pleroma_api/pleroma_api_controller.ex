# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.PleromaAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 7]

  alias Pleroma.Conversation.Participation
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.ConversationView
  alias Pleroma.Web.MastodonAPI.StatusView

  def conversation_statuses(
        %{assigns: %{user: user}} = conn,
        %{"id" => participation_id} = params
      ) do
    params =
      params
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> Map.put("user", user)

    participation =
      participation_id
      |> Participation.get()
      |> Repo.preload(:conversation)

    if user.id == participation.user_id do
      activities =
        participation.conversation.ap_id
        |> ActivityPub.fetch_activities_for_context(params)
        |> Enum.reverse()

      conn
      |> add_link_headers(
        :conversation_statuses,
        activities,
        participation_id,
        params,
        nil,
        &pleroma_api_url/4
      )
      |> put_view(StatusView)
      |> render("index.json", %{activities: activities, for: user, as: :activity})
    end
  end

  def update_conversation(
        %{assigns: %{user: user}} = conn,
        %{"id" => participation_id, "recipients" => recipients}
      ) do
    participation =
      participation_id
      |> Participation.get()

    with true <- user.id == participation.user_id,
         {:ok, _} <- Participation.set_recipients(participation, recipients) do
      conn
      |> put_view(ConversationView)
      |> render("participation.json", %{participation: participation, user: user})
    end
  end
end
