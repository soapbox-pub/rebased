defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
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

  def handle(%{data: %{"type" => "Undo", "object" => undone_object}} = object, meta) do
    with undone_object <- Activity.get_by_ap_id(undone_object),
         :ok <- handle_undoing(undone_object) do
      {:ok, object, meta}
    end
  end

  # Nothing to do
  def handle(object, meta) do
    {:ok, object, meta}
  end

  def handle_undoing(%{data: %{"type" => "Like"}} = object) do
    with %Object{} = liked_object <- Object.get_by_ap_id(object.data["object"]),
         {:ok, _} <- Utils.remove_like_from_object(object, liked_object),
         {:ok, _} <- Repo.delete(object) do
      :ok
    end
  end

  def handle_undoing(object), do: {:error, ["don't know how to handle", object]}
end
