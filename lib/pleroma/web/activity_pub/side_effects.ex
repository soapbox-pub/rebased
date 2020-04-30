defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.ActivityPub

  def handle(object, meta \\ [])

  # Tasks this handles:
  # - Add like to object
  # - Set up notification
  def handle(%{data: %{"type" => "Like"}} = object, meta) do
    {:ok, result} =
      Pleroma.Repo.transaction(fn ->
        liked_object = Object.get_by_ap_id(object.data["object"])
        Utils.add_like_to_object(object, liked_object)

        Notification.create_notifications(object)

        {:ok, object, meta}
      end)

    result
  end

  # Tasks this handles:
  # - Delete and unpins the create activity
  # - Replace object with Tombstone
  # - Set up notification
  # - Reduce the user note count
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
end
