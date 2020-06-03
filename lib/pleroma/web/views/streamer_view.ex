# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.ChatMessageReference
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.NotificationView

  def render("chat_update.json", object, user, recipients) do
    chat = Chat.get(user.id, hd(recipients -- [user.ap_id]))

    # Explicitly giving the cmr for the object here, so we don't accidentally
    # send a later 'last_message' that was inserted between inserting this and
    # streaming it out
    cm_ref = ChatMessageReference.for_chat_and_object(chat, object)

    representation =
      Pleroma.Web.PleromaAPI.ChatView.render(
        "show.json",
        %{last_message: cm_ref, chat: chat}
      )

    %{
      event: "pleroma:chat_update",
      payload:
        representation
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("update.json", %Activity{} = activity, %User{} = user) do
    %{
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity,
          for: user
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("notification.json", %Notification{} = notify, %User{} = user) do
    %{
      event: "notification",
      payload:
        NotificationView.render(
          "show.json",
          %{notification: notify, for: user}
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("update.json", %Activity{} = activity) do
    %{
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("conversation.json", %Participation{} = participation) do
    %{
      event: "conversation",
      payload:
        Pleroma.Web.MastodonAPI.ConversationView.render("participation.json", %{
          participation: participation,
          for: participation.user
        })
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end
end
