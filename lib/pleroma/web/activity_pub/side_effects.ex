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
  # - Delete create activity
  # - Replace object with Tombstone
  # - Set up notification
  def handle(%{data: %{"type" => "Delete", "object" => deleted_object}} = object, meta) do
    deleted_object =
      Object.normalize(deleted_object, false) || User.get_cached_by_ap_id(deleted_object)

    result =
      case deleted_object do
        %Object{} ->
          with {:ok, _, _} <- Object.delete(deleted_object) do
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
