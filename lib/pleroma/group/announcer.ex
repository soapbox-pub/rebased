# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.Announcer do
  @moduledoc """
  Disseminates content to group members by announcing it.
  """
  alias Pleroma.Group
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  @object_types ~w[ChatMessage Question Answer Audio Video Event Article Note Join Leave Add Remove Delete]

  def should_announce(%Group{} = group, %{data: %{"type" => type, "actor" => actor}})
      when type in @object_types do
    with {:actor, %User{} = actor} <- {:actor, User.get_cached_by_ap_id(actor)},
         {:membership, true} <- {:membership, Group.is_member?(group, user)} do
      true
    else
      _ -> false
    end
  end

  def should_announce(_group, _object), do: false

  def announce(group, object) do
    if should_announce(group, object), do: do_announce(group, object), else: {:noop, object}
  end

  defp do_announce(%Group{user: %User{} = user}, object) do
    CommonAPI.repeat()
  end
end
