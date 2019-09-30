# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("participations.json", %{participations: participations, for: user}) do
    render_many(participations, __MODULE__, "participation.json", as: :participation, for: user)
  end

  def render("participation.json", %{participation: participation, for: user}) do
    participation = Repo.preload(participation, conversation: [], recipients: [])

    last_activity_id =
      with nil <- participation.last_activity_id do
        ActivityPub.fetch_latest_activity_id_for_context(participation.conversation.ap_id, %{
          "user" => user,
          "blocking_user" => user
        })
      end

    activity = Activity.get_by_id_with_object(last_activity_id)
    # Conversations return all users except the current user.
    users = Enum.reject(participation.recipients, &(&1.id == user.id))

    %{
      id: participation.id |> to_string(),
      accounts: render(AccountView, "index.json", users: users, as: :user),
      unread: !participation.read,
      last_status: render(StatusView, "show.json", activity: activity, for: user)
    }
  end
end
