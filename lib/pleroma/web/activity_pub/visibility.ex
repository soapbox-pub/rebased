# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Visibility do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils

  require Pleroma.Constants

  @spec is_public?(Object.t() | Activity.t() | map()) :: boolean()
  def is_public?(%Object{data: %{"type" => "Tombstone"}}), do: false
  def is_public?(%Object{data: data}), do: is_public?(data)
  def is_public?(%Activity{data: data}), do: is_public?(data)
  def is_public?(%{"directMessage" => true}), do: false
  def is_public?(data), do: Utils.label_in_message?(Pleroma.Constants.as_public(), data)

  def is_private?(activity) do
    with false <- is_public?(activity),
         %User{follower_address: follower_address} <-
           User.get_cached_by_ap_id(activity.data["actor"]) do
      follower_address in activity.data["to"]
    else
      _ -> false
    end
  end

  def is_announceable?(activity, user, public \\ true) do
    is_public?(activity) ||
      (!public && is_private?(activity) && activity.data["actor"] == user.ap_id)
  end

  def is_direct?(%Activity{data: %{"directMessage" => true}}), do: true
  def is_direct?(%Object{data: %{"directMessage" => true}}), do: true

  def is_direct?(activity) do
    !is_public?(activity) && !is_private?(activity)
  end

  def is_list?(%{data: %{"listMessage" => _}}), do: true
  def is_list?(_), do: false

  def visible_for_user?(%{actor: ap_id}, %User{ap_id: ap_id}), do: true

  def visible_for_user?(%{data: %{"listMessage" => list_ap_id}} = activity, %User{} = user) do
    user.ap_id in activity.data["to"] ||
      list_ap_id
      |> Pleroma.List.get_by_ap_id()
      |> Pleroma.List.member?(user)
  end

  def visible_for_user?(%{data: %{"listMessage" => _}}, nil), do: false

  def visible_for_user?(activity, nil) do
    is_public?(activity)
  end

  def visible_for_user?(activity, user) do
    x = [user.ap_id | user.following]
    y = [activity.actor] ++ activity.data["to"] ++ (activity.data["cc"] || [])
    visible_for_user?(activity, nil) || Enum.any?(x, &(&1 in y))
  end

  def entire_thread_visible_for_user?(%Activity{} = activity, %User{} = user) do
    {:ok, %{rows: [[result]]}} =
      Ecto.Adapters.SQL.query(Repo, "SELECT thread_visibility($1, $2)", [
        user.ap_id,
        activity.data["id"]
      ])

    result
  end

  def get_visibility(object) do
    to = object.data["to"] || []
    cc = object.data["cc"] || []

    cond do
      Pleroma.Constants.as_public() in to ->
        "public"

      Pleroma.Constants.as_public() in cc ->
        "unlisted"

      # this should use the sql for the object's activity
      Enum.any?(to, &String.contains?(&1, "/followers")) ->
        "private"

      object.data["directMessage"] == true ->
        "direct"

      is_binary(object.data["listMessage"]) ->
        "list"

      length(cc) > 0 ->
        "private"

      true ->
        "direct"
    end
  end
end
