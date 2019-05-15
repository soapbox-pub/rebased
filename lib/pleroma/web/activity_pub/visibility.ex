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

  # XXX: Probably even more inefficient than the previous implementation intended to be a placeholder untill https://git.pleroma.social/pleroma/pleroma/merge_requests/971 is in develop
  # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength

  def entire_thread_visible_for_user?(
        %Activity{} = tail,
        # %Activity{data: %{"object" => %{"inReplyTo" => parent_id}}} = tail,
        user
      ) do
    case Object.normalize(tail) do
      %{data: %{"inReplyTo" => parent_id}} when is_binary(parent_id) ->
        parent = Activity.get_in_reply_to_activity(tail)
        visible_for_user?(tail, user) && entire_thread_visible_for_user?(parent, user)

      _ ->
        visible_for_user?(tail, user)
    end
  end

  def get_visibility(object) do
    public = "https://www.w3.org/ns/activitystreams#Public"
    to = object.data["to"] || []
    cc = object.data["cc"] || []

    cond do
      public in to ->
        "public"

      public in cc ->
        "unlisted"

      # this should use the sql for the object's activity
      Enum.any?(to, &String.contains?(&1, "/followers")) ->
        "private"

      length(cc) > 0 ->
        "private"

      true ->
        "direct"
    end
  end
end
