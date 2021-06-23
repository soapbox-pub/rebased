# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.Announcer do
  @moduledoc """
  Disseminates content to group members by announcing it.
  """
  alias Pleroma.Group
  alias Pleroma.User

  @object_types ~w[ChatMessage Question Answer Audio Video Event Article Note Join Leave Add Remove Delete]

  def should_announce?(%Group{id: group_id} = group, %{"type" => type} = object)
      when type in @object_types do
    with %Group{id: ^group_id} <- Group.get_object_group(object),
         %User{} = user <- User.get_cached_by_ap_id(object["actor"]),
         true <- Group.is_member?(group, user) do
      true
    else
      _ -> false
    end
  end

  def should_announce?(_group, _object), do: false

  def announce(%Group{user: %User{} = _user}, _object) do
    # TODO
    # CommonAPI.repeat()
  end

  def maybe_announce(group, object) do
    if should_announce?(group, object), do: announce(group, object), else: {:noop, object}
  end
end
