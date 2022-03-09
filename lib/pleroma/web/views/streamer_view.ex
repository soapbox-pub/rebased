# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.NotificationView

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

  def render("chat_update.json", %{chat_message_reference: cm_ref}) do
    # Explicitly giving the cmr for the object here, so we don't accidentally
    # send a later 'last_message' that was inserted between inserting this and
    # streaming it out
    #
    # It also contains the chat with a cache of the correct unread count
    Logger.debug("Trying to stream out #{inspect(cm_ref)}")

    representation =
      Pleroma.Web.PleromaAPI.ChatView.render(
        "show.json",
        %{last_message: cm_ref, chat: cm_ref.chat}
      )

    %{
      event: "pleroma:chat_update",
      payload:
        representation
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("follow_relationships_update.json", item) do
    %{
      event: "pleroma:follow_relationships_update",
      payload:
        %{
          state: item.state,
          follower: %{
            id: item.follower.id,
            follower_count: item.follower.follower_count,
            following_count: item.follower.following_count
          },
          following: %{
            id: item.following.id,
            follower_count: item.following.follower_count,
            following_count: item.following.following_count
          }
        }
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
