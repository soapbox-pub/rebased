defmodule Pleroma.Web.ActivityPub.SideEffects do
  @moduledoc """
  This module looks at an inserted object and executes the side effects that it
  implies. For example, a `Like` activity will increase the like count on the
  liked object, a `Follow` activity will add the user to the follower
  collection, and so on.
  """
  alias Pleroma.Notification
  alias Pleroma.Object
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

  # Nothing to do
  def handle(object, meta) do
    {:ok, object, meta}
  end
end
