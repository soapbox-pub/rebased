defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils

  def handle(object, meta \\ [])

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
    with {:ok, _object, _meta} <- handle_object_creation(meta[:object_data], meta) do
      Notification.create_notifications(activity)
      {:ok, activity, meta}
    else
      e -> Repo.rollback(e)
    end
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

      [[actor, recipient], [recipient, actor]]
      |> Enum.each(fn [user, other_user] ->
        if user.local do
          Chat.bump_or_create(user.id, other_user.ap_id)
        end
      end)

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
end
