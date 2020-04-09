defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Chat
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
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

  def handle(%{data: %{"type" => "Create", "object" => object_id}} = activity, meta) do
    object = Object.get_by_ap_id(object_id)

    {:ok, _object} = handle_object_creation(object)

    {:ok, activity, meta}
  end

  # Nothing to do
  def handle(object, meta) do
    {:ok, object, meta}
  end

  def handle_object_creation(%{data: %{"type" => "ChatMessage"}} = object) do
    actor = User.get_cached_by_ap_id(object.data["actor"])
    recipient = User.get_cached_by_ap_id(hd(object.data["to"]))

    [[actor, recipient], [recipient, actor]]
    |> Enum.each(fn [user, other_user] ->
      if user.local do
        Chat.bump_or_create(user.id, other_user.ap_id)
      end
    end)

    {:ok, object}
  end

  # Nothing to do
  def handle_object_creation(object) do
    {:ok, object}
  end
end
