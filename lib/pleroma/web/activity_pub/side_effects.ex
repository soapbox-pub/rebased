# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.FollowingRelationship
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Push
  alias Pleroma.Web.Streamer
  alias Pleroma.Workers.PollWorker

  require Logger

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @logger Pleroma.Config.get([:side_effects, :logger], Logger)

  @behaviour Pleroma.Web.ActivityPub.SideEffects.Handling

  defp ap_streamer, do: Pleroma.Config.get([:side_effects, :ap_streamer], ActivityPub)

  @impl true
  def handle(object, meta \\ [])

  # Task this handles
  # - Follows
  # - Sends a notification
  @impl true
  def handle(
        %{
          data: %{
            "actor" => actor,
            "type" => "Accept",
            "object" => follow_activity_id
          }
        } = object,
        meta
      ) do
    with %Activity{actor: follower_id} = follow_activity <-
           Activity.get_by_ap_id(follow_activity_id),
         %User{} = followed <- User.get_cached_by_ap_id(actor),
         %User{} = follower <- User.get_cached_by_ap_id(follower_id),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "accept"),
         {:ok, _follower, followed} <-
           FollowingRelationship.update(follower, followed, :follow_accept) do
      Notification.update_notification_type(followed, follow_activity)
    end

    {:ok, object, meta}
  end

  # Task this handles
  # - Rejects all existing follow activities for this person
  # - Updates the follow state
  # - Dismisses notification
  @impl true
  def handle(
        %{
          data: %{
            "actor" => actor,
            "type" => "Reject",
            "object" => follow_activity_id
          }
        } = object,
        meta
      ) do
    with %Activity{actor: follower_id} = follow_activity <-
           Activity.get_by_ap_id(follow_activity_id),
         %User{} = followed <- User.get_cached_by_ap_id(actor),
         %User{} = follower <- User.get_cached_by_ap_id(follower_id),
         {:ok, _follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "reject") do
      FollowingRelationship.update(follower, followed, :follow_reject)
      Notification.dismiss(follow_activity)
    end

    {:ok, object, meta}
  end

  # Tasks this handle
  # - Follows if possible
  # - Sends a notification
  # - Generates accept or reject if appropriate
  @impl true
  def handle(
        %{
          data: %{
            "id" => follow_id,
            "type" => "Follow",
            "object" => followed_user,
            "actor" => following_user
          }
        } = object,
        meta
      ) do
    with %User{} = follower <- User.get_cached_by_ap_id(following_user),
         %User{} = followed <- User.get_cached_by_ap_id(followed_user),
         {_, {:ok, _, _}, _, _} <-
           {:following, User.follow(follower, followed, :follow_pending), follower, followed} do
      if followed.local && !followed.is_locked do
        {:ok, accept_data, _} = Builder.accept(followed, object)
        {:ok, _activity, _} = Pipeline.common_pipeline(accept_data, local: true)
      end
    else
      {:following, {:error, _}, _follower, followed} ->
        {:ok, reject_data, _} = Builder.reject(followed, object)
        {:ok, _activity, _} = Pipeline.common_pipeline(reject_data, local: true)

      _ ->
        nil
    end

    {:ok, notifications} = Notification.create_notifications(object, do_send: false)

    meta =
      meta
      |> add_notifications(notifications)

    updated_object = Activity.get_by_ap_id(follow_id)

    {:ok, updated_object, meta}
  end

  # Tasks this handles:
  # - Unfollow and block
  @impl true
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
  @impl true
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
  @impl true
  def handle(%{data: %{"type" => "Like"}} = object, meta) do
    liked_object = Object.get_by_ap_id(object.data["object"])
    Utils.add_like_to_object(object, liked_object)

    Notification.create_notifications(object)

    {:ok, object, meta}
  end

  # Tasks this handles
  # - Actually create object
  # - Rollback if we couldn't create it
  # - Increase the user note count
  # - Increase the reply count
  # - Increase replies count
  # - Set up ActivityExpiration
  # - Set up notifications
  @impl true
  def handle(%{data: %{"type" => "Create"}} = activity, meta) do
    with {:ok, object, meta} <- handle_object_creation(meta[:object_data], activity, meta),
         %User{} = user <- User.get_cached_by_ap_id(activity.data["actor"]) do
      {:ok, notifications} = Notification.create_notifications(activity, do_send: false)
      {:ok, _user} = ActivityPub.increase_note_count_if_public(user, object)
      {:ok, _user} = ActivityPub.update_last_status_at_if_public(user, object)

      if in_reply_to = object.data["type"] != "Answer" && object.data["inReplyTo"] do
        Object.increase_replies_count(in_reply_to)
      end

      reply_depth = (meta[:depth] || 0) + 1

      # FIXME: Force inReplyTo to replies
      if Pleroma.Web.Federator.allowed_thread_distance?(reply_depth) and
           object.data["replies"] != nil do
        for reply_id <- object.data["replies"] do
          Pleroma.Workers.RemoteFetcherWorker.enqueue("fetch_remote", %{
            "id" => reply_id,
            "depth" => reply_depth
          })
        end
      end

      ConcurrentLimiter.limit(Pleroma.Web.RichMedia.Helpers, fn ->
        Task.start(fn -> Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity) end)
      end)

      meta =
        meta
        |> add_notifications(notifications)

      ap_streamer().stream_out(activity)

      {:ok, activity, meta}
    else
      e -> Repo.rollback(e)
    end
  end

  # Tasks this handles:
  # - Add announce to object
  # - Set up notification
  # - Stream out the announce
  @impl true
  def handle(%{data: %{"type" => "Announce"}} = object, meta) do
    announced_object = Object.get_by_ap_id(object.data["object"])
    user = User.get_cached_by_ap_id(object.data["actor"])

    Utils.add_announce_to_object(object, announced_object)

    if !User.is_internal_user?(user) do
      Notification.create_notifications(object)

      ap_streamer().stream_out(object)
    end

    {:ok, object, meta}
  end

  @impl true
  def handle(%{data: %{"type" => "Undo", "object" => undone_object}} = object, meta) do
    with undone_object <- Activity.get_by_ap_id(undone_object),
         :ok <- handle_undoing(undone_object) do
      {:ok, object, meta}
    end
  end

  # Tasks this handles:
  # - Add reaction to object
  # - Set up notification
  @impl true
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
  @impl true
  def handle(%{data: %{"type" => "Delete", "object" => deleted_object}} = object, meta) do
    deleted_object =
      Object.normalize(deleted_object, fetch: false) ||
        User.get_cached_by_ap_id(deleted_object)

    result =
      case deleted_object do
        %Object{} ->
          with {:ok, deleted_object, _activity} <- Object.delete(deleted_object),
               {_, actor} when is_binary(actor) <- {:actor, deleted_object.data["actor"]},
               %User{} = user <- User.get_cached_by_ap_id(actor) do
            User.remove_pinned_object_id(user, deleted_object.data["id"])

            {:ok, user} = ActivityPub.decrease_note_count_if_public(user, deleted_object)

            if in_reply_to = deleted_object.data["inReplyTo"] do
              Object.decrease_replies_count(in_reply_to)
            end

            MessageReference.delete_for_object(deleted_object)

            ap_streamer().stream_out(object)
            ap_streamer().stream_out_participations(deleted_object, user)
            :ok
          else
            {:actor, _} ->
              @logger.error("The object doesn't have an actor: #{inspect(deleted_object)}")
              :no_object_actor
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

  # Tasks this handles:
  # - adds pin to user
  # - removes expiration job for pinned activity, if was set for expiration
  @impl true
  def handle(%{data: %{"type" => "Add"} = data} = object, meta) do
    with %User{} = user <- User.get_cached_by_ap_id(data["actor"]),
         {:ok, _user} <- User.add_pinned_object_id(user, data["object"]) do
      # if pinned activity was scheduled for deletion, we remove job
      if expiration = Pleroma.Workers.PurgeExpiredActivity.get_expiration(meta[:activity_id]) do
        Oban.cancel_job(expiration.id)
      end

      {:ok, object, meta}
    else
      nil ->
        {:error, :user_not_found}

      {:error, changeset} ->
        if changeset.errors[:pinned_objects] do
          {:error, :pinned_statuses_limit_reached}
        else
          changeset.errors
        end
    end
  end

  # Tasks this handles:
  # - removes pin from user
  # - removes corresponding Add activity
  # - if activity had expiration, recreates activity expiration job
  @impl true
  def handle(%{data: %{"type" => "Remove"} = data} = object, meta) do
    with %User{} = user <- User.get_cached_by_ap_id(data["actor"]),
         {:ok, _user} <- User.remove_pinned_object_id(user, data["object"]) do
      data["object"]
      |> Activity.add_by_params_query(user.ap_id, user.featured_address)
      |> Repo.delete_all()

      # if pinned activity was scheduled for deletion, we reschedule it for deletion
      if meta[:expires_at] do
        # MRF.ActivityExpirationPolicy used UTC timestamps for expires_at in original implementation
        {:ok, expires_at} =
          Pleroma.EctoType.ActivityPub.ObjectValidators.DateTime.cast(meta[:expires_at])

        Pleroma.Workers.PurgeExpiredActivity.enqueue(%{
          activity_id: meta[:activity_id],
          expires_at: expires_at
        })
      end

      {:ok, object, meta}
    else
      nil -> {:error, :user_not_found}
      error -> error
    end
  end

  # Nothing to do
  @impl true
  def handle(object, meta) do
    {:ok, object, meta}
  end

  def handle_object_creation(%{"type" => "ChatMessage"} = object, _activity, meta) do
    with {:ok, object, meta} <- Pipeline.common_pipeline(object, meta) do
      actor = User.get_cached_by_ap_id(object.data["actor"])
      recipient = User.get_cached_by_ap_id(hd(object.data["to"]))

      streamables =
        [[actor, recipient], [recipient, actor]]
        |> Enum.uniq()
        |> Enum.map(fn [user, other_user] ->
          if user.local do
            {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
            {:ok, cm_ref} = MessageReference.create(chat, object, user.ap_id != actor.ap_id)

            @cachex.put(
              :chat_message_id_idempotency_key_cache,
              cm_ref.id,
              meta[:idempotency_key]
            )

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

  def handle_object_creation(%{"type" => "Question"} = object, activity, meta) do
    with {:ok, object, meta} <- Pipeline.common_pipeline(object, meta) do
      PollWorker.schedule_poll_end(activity)
      {:ok, object, meta}
    end
  end

  def handle_object_creation(%{"type" => "Answer"} = object_map, _activity, meta) do
    with {:ok, object, meta} <- Pipeline.common_pipeline(object_map, meta) do
      Object.increase_vote_count(
        object.data["inReplyTo"],
        object.data["name"],
        object.data["actor"]
      )

      {:ok, object, meta}
    end
  end

  def handle_object_creation(%{"type" => objtype} = object, _activity, meta)
      when objtype in ~w[Audio Video Event Article Note Page] do
    with {:ok, object, meta} <- Pipeline.common_pipeline(object, meta) do
      {:ok, object, meta}
    end
  end

  # Nothing to do
  def handle_object_creation(object, _activity, meta) do
    {:ok, object, meta}
  end

  defp undo_like(nil, object), do: delete_object(object)

  defp undo_like(%Object{} = liked_object, object) do
    with {:ok, _} <- Utils.remove_like_from_object(object, liked_object) do
      delete_object(object)
    end
  end

  def handle_undoing(%{data: %{"type" => "Like"}} = object) do
    object.data["object"]
    |> Object.get_by_ap_id()
    |> undo_like(object)
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

  @spec delete_object(Object.t()) :: :ok | {:error, Ecto.Changeset.t()}
  defp delete_object(object) do
    with {:ok, _} <- Repo.delete(object), do: :ok
  end

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

  @impl true
  def handle_after_transaction(meta) do
    meta
    |> send_notifications()
    |> send_streamables()
  end
end
