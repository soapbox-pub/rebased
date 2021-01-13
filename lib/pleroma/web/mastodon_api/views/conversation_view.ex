# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("participations.json", %{participations: participations, for: user}) do
    safe_render_many(participations, __MODULE__, "participation.json", %{
      as: :participation,
      for: user
    })
  end

  def render("participation.json", %{participation: participation, for: user}) do
    participation = Repo.preload(participation, conversation: [], recipients: [])

    last_activity_id =
      with nil <- participation.last_activity_id do
        ActivityPub.fetch_latest_direct_activity_id_for_context(
          participation.conversation.ap_id,
          %{
            user: user,
            blocking_user: user
          }
        )
      end

    activity = Activity.get_by_id_with_object(last_activity_id)

    # Conversations return all users except the current user,
    # except when the current user is the only participant
    users =
      if length(participation.recipients) > 1 do
        Enum.reject(participation.recipients, &(&1.id == user.id))
      else
        participation.recipients
      end

    %{
      id: participation.id |> to_string(),
      accounts: render(AccountView, "index.json", users: users, for: user),
      unread: !participation.read,
      last_status:
        render(StatusView, "show.json",
          activity: activity,
          direct_conversation_id: participation.id,
          for: user
        )
    }
  end
end
