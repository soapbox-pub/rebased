# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.PleromaAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.ConversationView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"]}
    when action in [:conversation, :conversation_statuses]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:statuses"]}
    when action in [:react_with_emoji, :unreact_with_emoji]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:conversations"]} when action == :update_conversation
  )

  plug(OAuthScopesPlug, %{scopes: ["write:notifications"]} when action == :read_notification)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  def emoji_reactions_by(%{assigns: %{user: user}} = conn, %{"id" => activity_id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         %Object{data: %{"reactions" => emoji_reactions}} when is_list(emoji_reactions) <-
           Object.normalize(activity) do
      reactions =
        emoji_reactions
        |> Enum.map(fn [emoji, user_ap_ids] ->
          users =
            Enum.map(user_ap_ids, &User.get_cached_by_ap_id/1)
            |> Enum.filter(& &1)

          %{
            name: emoji,
            count: length(users),
            accounts: AccountView.render("index.json", %{users: users, for: user, as: :user}),
            me: !!(user && user.ap_id in user_ap_ids)
          }
        end)

      conn
      |> json(reactions)
    else
      _e ->
        conn
        |> json([])
    end
  end

  def react_with_emoji(%{assigns: %{user: user}} = conn, %{"id" => activity_id, "emoji" => emoji}) do
    with {:ok, _activity, _object} <- CommonAPI.react_with_emoji(activity_id, user, emoji),
         activity <- Activity.get_by_id(activity_id) do
      conn
      |> put_view(StatusView)
      |> render("show.json", %{activity: activity, for: user, as: :activity})
    end
  end

  def unreact_with_emoji(%{assigns: %{user: user}} = conn, %{
        "id" => activity_id,
        "emoji" => emoji
      }) do
    with {:ok, _activity, _object} <- CommonAPI.unreact_with_emoji(activity_id, user, emoji),
         activity <- Activity.get_by_id(activity_id) do
      conn
      |> put_view(StatusView)
      |> render("show.json", %{activity: activity, for: user, as: :activity})
    end
  end

  def conversation(%{assigns: %{user: user}} = conn, %{"id" => participation_id}) do
    with %Participation{} = participation <- Participation.get(participation_id),
         true <- user.id == participation.user_id do
      conn
      |> put_view(ConversationView)
      |> render("participation.json", %{participation: participation, for: user})
    end
  end

  def conversation_statuses(
        %{assigns: %{user: user}} = conn,
        %{"id" => participation_id} = params
      ) do
    participation = Participation.get(participation_id, preload: [:conversation])

    if user.id == participation.user_id do
      params =
        params
        |> Map.put("blocking_user", user)
        |> Map.put("muting_user", user)
        |> Map.put("user", user)

      activities =
        participation.conversation.ap_id
        |> ActivityPub.fetch_activities_for_context(params)
        |> Enum.reverse()

      conn
      |> add_link_headers(activities)
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
         {:ok, participation} <- Participation.set_recipients(participation, recipients) do
      conn
      |> put_view(ConversationView)
      |> render("participation.json", %{participation: participation, for: user})
    end
  end

  def read_conversations(%{assigns: %{user: user}} = conn, _params) do
    with {:ok, _, participations} <- Participation.mark_all_as_read(user) do
      conn
      |> add_link_headers(participations)
      |> put_view(ConversationView)
      |> render("participations.json", participations: participations, for: user)
    end
  end

  def read_notification(%{assigns: %{user: user}} = conn, %{"id" => notification_id}) do
    with {:ok, notification} <- Notification.read_one(user, notification_id) do
      conn
      |> put_view(NotificationView)
      |> render("show.json", %{notification: notification, for: user})
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => message})
    end
  end

  def read_notification(%{assigns: %{user: user}} = conn, %{"max_id" => max_id}) do
    with notifications <- Notification.set_read_up_to(user, max_id) do
      notifications = Enum.take(notifications, 80)

      conn
      |> put_view(NotificationView)
      |> render("index.json", %{notifications: notifications, for: user})
    end
  end
end
