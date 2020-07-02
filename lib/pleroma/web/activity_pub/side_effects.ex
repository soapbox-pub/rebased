defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Push
  alias Pleroma.Web.Streamer

  def handle(object, meta \\ [])

  # Tasks this handles:
  # - Unfollow and block
  def handle(
        %{data: %{"type" => "Block", "object" => blocked_user, "actor" => blocking_user}} =
          object,
        meta
      ) do
    with %User{} = blocker <- User.get_cached_by_ap_id(blocking_user),
         %User{} = blocked <- User.get_cached_by_ap_id(blocked_user) do
      User.block(blocker, blocked)
    end

    {:ok, object, meta}
  end

  # Tasks this handles:
  # - Update the user
  #
  # For a local user, we also get a changeset with the full information, so we
  # can update non-federating, non-activitypub settings as well.
  def handle(%{data: %{"type" => "Update", "object" => updated_object}} = object, meta) do
    if changeset = Keyword.get(meta, :user_update_changeset) do
      changeset
      |> User.update_and_set_cache()
    else
      {:ok, new_user_data} = ActivityPub.user_data_from_user_object(updated_object)

      User.get_by_ap_id(updated_object["id"])
      |> User.remote_user_changeset(new_user_data)
      |> User.update_and_set_cache()
    end

    {:ok, object, meta}
  end

  # Tasks this handles:
  # - Add like to object
  # - Set up notification
  def handle(%{data: %{"type" => "Like"}} = object, meta) do
    liked_object = Object.get_by_ap_id(object.data["object"])
    Utils.add_like_to_object(object, liked_object)

    Notification.create_notifications(object)

    {:ok, object, meta}
  end

  # Tasks this handles
  # - Actually create object
  # - Rollback if we couldn't create it
  # - Set up notifications
  def handle(%{data: %{"type" => "Create"}} = activity, meta) do
    with {:ok, _object, meta} <- handle_object_creation(meta[:object_data], meta) do
      {:ok, notifications} = Notification.create_notifications(activity, do_send: false)

      meta =
        meta
        |> add_notifications(notifications)

      {:ok, activity, meta}
    else
      e -> Repo.rollback(e)
    end
  end

  # Tasks this handles:
  # - Add announce to object
  # - Set up notification
  # - Stream out the announce
  def handle(%{data: %{"type" => "Announce"}} = object, meta) do
    announced_object = Object.get_by_ap_id(object.data["object"])
    user = User.get_cached_by_ap_id(object.data["actor"])

    Utils.add_announce_to_object(object, announced_object)

    if !User.is_internal_user?(user) do
      Notification.create_notifications(object)

      object
      |> Topics.get_activity_topics()
      |> Streamer.stream(object)
    end

    {:ok, object, meta}
  end

  def handle(%{data: %{"type" => "Undo", "object" => undone_object}} = object, meta) do
    with undone_object <- Activity.get_by_ap_id(undone_object),
         :ok <- handle_undoing(undone_object) do
      {:ok, object, meta}
    end
  end

  # Tasks this handles:
  # - Add reaction to object
  # - Set up notification
  def handle(%{data: %{"type" => "EmojiReact"}} = object, meta) do
    reacted_object = Object.get_by_ap_id(object.data["object"])
    Utils.add_emoji_reaction_to_object(object, reacted_object)

    Notification.create_notifications(object)

    {:ok, object, meta}
  end

  # Tasks this handles:
  # - Delete and unpins the create activity
  # - Replace object with Tombstone
  # - Set up notification
  # - Reduce the user note count
  # - Reduce the reply count
  # - Stream out the activity
  def handle(%{data: %{"type" => "Delete", "object" => deleted_object}} = object, meta) do
    deleted_object =
      Object.normalize(deleted_object, false) || User.get_cached_by_ap_id(deleted_object)

    result =
      case deleted_object do
        %Object{} ->
          with {:ok, deleted_object, activity} <- Object.delete(deleted_object),
               %User{} = user <- User.get_cached_by_ap_id(deleted_object.data["actor"]) do
            User.remove_pinnned_activity(user, activity)

            {:ok, user} = ActivityPub.decrease_note_count_if_public(user, deleted_object)

            if in_reply_to = deleted_object.data["inReplyTo"] do
              Object.decrease_replies_count(in_reply_to)
            end

            MessageReference.delete_for_object(deleted_object)

            ActivityPub.stream_out(object)
            ActivityPub.stream_out_participations(deleted_object, user)
            :ok
          end

        %User{} ->
          with {:ok, _} <- User.delete(deleted_object) do
            :ok
          end
      end

    if result == :ok do
      Notification.create_notifications(object)
      {:ok, object, meta}
    else
      {:error, result}
    end
  end

  # Nothing to do
  def handle(object, meta) do
    {:ok, object, meta}
  end

  def handle_object_creation(%{"type" => "ChatMessage"} = object, meta) do
    with {:ok, object, meta} <- Pipeline.common_pipeline(object, meta) do
      actor = User.get_cached_by_ap_id(object.data["actor"])
      recipient = User.get_cached_by_ap_id(hd(object.data["to"]))

      streamables =
        [[actor, recipient], [recipient, actor]]
        |> Enum.map(fn [user, other_user] ->
          if user.local do
            {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
            {:ok, cm_ref} = MessageReference.create(chat, object, user.ap_id != actor.ap_id)

            {
              ["user", "user:pleroma_chat"],
              {user, %{cm_ref | chat: chat, object: object}}
            }
          end
        end)
        |> Enum.filter(& &1)

      meta =
        meta
        |> add_streamables(streamables)

      {:ok, object, meta}
    end
  end

  # Nothing to do
  def handle_object_creation(object) do
    {:ok, object}
  end

  def handle_undoing(%{data: %{"type" => "Like"}} = object) do
    with %Object{} = liked_object <- Object.get_by_ap_id(object.data["object"]),
         {:ok, _} <- Utils.remove_like_from_object(object, liked_object),
         {:ok, _} <- Repo.delete(object) do
      :ok
    end
  end

  def handle_undoing(%{data: %{"type" => "EmojiReact"}} = object) do
    with %Object{} = reacted_object <- Object.get_by_ap_id(object.data["object"]),
         {:ok, _} <- Utils.remove_emoji_reaction_from_object(object, reacted_object),
         {:ok, _} <- Repo.delete(object) do
      :ok
    end
  end

  def handle_undoing(%{data: %{"type" => "Announce"}} = object) do
    with %Object{} = liked_object <- Object.get_by_ap_id(object.data["object"]),
         {:ok, _} <- Utils.remove_announce_from_object(object, liked_object),
         {:ok, _} <- Repo.delete(object) do
      :ok
    end
  end

  def handle_undoing(
        %{data: %{"type" => "Block", "actor" => blocker, "object" => blocked}} = object
      ) do
    with %User{} = blocker <- User.get_cached_by_ap_id(blocker),
         %User{} = blocked <- User.get_cached_by_ap_id(blocked),
         {:ok, _} <- User.unblock(blocker, blocked),
         {:ok, _} <- Repo.delete(object) do
      :ok
    end
  end

  def handle_undoing(object), do: {:error, ["don't know how to handle", object]}

  defp send_notifications(meta) do
    Keyword.get(meta, :notifications, [])
    |> Enum.each(fn notification ->
      Streamer.stream(["user", "user:notification"], notification)
      Push.send(notification)
    end)

    meta
  end

  defp send_streamables(meta) do
    Keyword.get(meta, :streamables, [])
    |> Enum.each(fn {topics, items} ->
      Streamer.stream(topics, items)
    end)

    meta
  end

  defp add_streamables(meta, streamables) do
    existing = Keyword.get(meta, :streamables, [])

    meta
    |> Keyword.put(:streamables, streamables ++ existing)
  end

  defp add_notifications(meta, notifications) do
    existing = Keyword.get(meta, :notifications, [])

    meta
    |> Keyword.put(:notifications, notifications ++ existing)
  end

  def handle_after_transaction(meta) do
    meta
    |> send_notifications()
    |> send_streamables()
  end
end
