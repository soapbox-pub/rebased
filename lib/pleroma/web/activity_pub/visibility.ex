defmodule Pleroma.Web.ActivityPub.Visibility do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User

  def is_public?(%Object{data: %{"type" => "Tombstone"}}), do: false
  def is_public?(%Object{data: data}), do: is_public?(data)
  def is_public?(%Activity{data: data}), do: is_public?(data)
  def is_public?(%{"directMessage" => true}), do: false

  def is_public?(data) do
    "https://www.w3.org/ns/activitystreams#Public" in (data["to"] ++ (data["cc"] || []))
  end

  def is_private?(activity) do
    unless is_public?(activity) do
      follower_address = User.get_cached_by_ap_id(activity.data["actor"]).follower_address
      Enum.any?(activity.data["to"], &(&1 == follower_address))
    else
      false
    end
  end

  def is_direct?(%Activity{data: %{"directMessage" => true}}), do: true
  def is_direct?(%Object{data: %{"directMessage" => true}}), do: true

  def is_direct?(activity) do
    !is_public?(activity) && !is_private?(activity)
  end

  def visible_for_user?(activity, nil) do
    is_public?(activity)
  end

  def visible_for_user?(activity, user) do
    x = [user.ap_id | user.following]
    y = [activity.actor] ++ activity.data["to"] ++ (activity.data["cc"] || [])
    visible_for_user?(activity, nil) || Enum.any?(x, &(&1 in y))
  end

  # guard
  def entire_thread_visible_for_user?(nil, _user), do: false

  # child
  def entire_thread_visible_for_user?(
        %Activity{data: %{"object" => %{"inReplyTo" => parent_id}}} = tail,
        user
      )
      when is_binary(parent_id) do
    parent = Activity.get_in_reply_to_activity(tail)
    visible_for_user?(tail, user) && entire_thread_visible_for_user?(parent, user)
  end

  # root
  def entire_thread_visible_for_user?(tail, user), do: visible_for_user?(tail, user)
end
