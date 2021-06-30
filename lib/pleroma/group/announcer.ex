# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.Announcer do
  @moduledoc """
  Disseminates content to group members by announcing it.
  """
  alias Pleroma.Group
  alias Pleroma.Group.Privacy
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils

  @object_types [
    "ChatMessage",
    "Question",
    "Answer",
    "Audio",
    "Video",
    "Event",
    "Article",
    "Note",
    "Delete"
  ]

  def should_announce?(%Group{id: group_id} = group, %{"type" => type} = object)
      when type in @object_types do
    with %Group{id: ^group_id} <- Group.get_object_group(object),
         %User{} = user <- User.get_cached_by_ap_id(object["actor"]),
         true <- Group.is_member?(group, user),
         true <- Privacy.matches_privacy?(group, object) do
      true
    else
      _ -> false
    end
  end

  def should_announce?(_group, _object), do: false

  def announce(%Group{} = group, object) when is_map(object) do
    %{
      "type" => "Announce",
      "id" => Utils.generate_activity_id(),
      "actor" => group.ap_id,
      "object" => object["id"],
      "to" => [group.members_collection],
      "context" => object["context"],
      "published" => Utils.make_date()
    }
    |> Pipeline.common_pipeline(local: true)
  end

  def announce(group, object), do: {:error, %{group: group, object: object}}

  def maybe_announce(group, object) do
    if should_announce?(group, object), do: announce(group, object), else: {:noop, object}
  end
end
