# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Marker
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.NotificationView

  require Pleroma.Constants

  def render("update.json", %Activity{} = activity, %User{} = user, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
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

  def render("status_update.json", %Activity{} = activity, %User{} = user, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
      event: "status.update",
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

  def render("notification.json", %Notification{} = notify, %User{} = user, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
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

  def render("update.json", %Activity{} = activity, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
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

  def render("status_update.json", %Activity{} = activity, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
      event: "status.update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("chat_update.json", %{chat_message_reference: cm_ref}, topic) do
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
      stream: render("stream.json", %{topic: topic}),
      event: "pleroma:chat_update",
      payload:
        representation
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("follow_relationships_update.json", item, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
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

  def render("conversation.json", %Participation{} = participation, topic) do
    %{
      stream: render("stream.json", %{topic: topic}),
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

  def render("marker.json", %Marker{} = marker) do
    %{
      event: "marker",
      payload:
        Pleroma.Web.MastodonAPI.MarkerView.render(
          "markers.json",
          markers: [marker]
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("pleroma_respond.json", %{type: type, result: result} = params) do
    %{
      event: "pleroma:respond",
      payload:
        %{
          result: result,
          type: type
        }
        |> Map.merge(maybe_error(params))
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("stream.json", %{topic: "user:pleroma_chat:" <> _}), do: ["user:pleroma_chat"]
  def render("stream.json", %{topic: "user:notification:" <> _}), do: ["user:notification"]
  def render("stream.json", %{topic: "user:" <> _}), do: ["user"]
  def render("stream.json", %{topic: "direct:" <> _}), do: ["direct"]
  def render("stream.json", %{topic: "list:" <> id}), do: ["list", id]
  def render("stream.json", %{topic: "hashtag:" <> tag}), do: ["hashtag", tag]

  def render("stream.json", %{topic: "public:remote:media:" <> instance}),
    do: ["public:remote:media", instance]

  def render("stream.json", %{topic: "public:remote:" <> instance}),
    do: ["public:remote", instance]

  def render("stream.json", %{topic: stream}) when stream in Pleroma.Constants.public_streams(),
    do: [stream]

  defp maybe_error(%{error: :bad_topic}), do: %{error: "bad_topic"}
  defp maybe_error(%{error: :unauthorized}), do: %{error: "unauthorized"}
  defp maybe_error(%{error: :already_authenticated}), do: %{error: "already_authenticated"}
  defp maybe_error(_), do: %{}
end
