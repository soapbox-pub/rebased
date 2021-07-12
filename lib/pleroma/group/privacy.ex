# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.Privacy do
  @moduledoc """
  Validate that ActivityPub objects match a group's privacy settings.
  """
  alias Pleroma.Group
  alias Pleroma.Object

  def matches_privacy?(%Group{privacy: "public"}, _object), do: true

  def matches_privacy?(%Group{} = group, object) when is_map(object) do
    with {recipients, _to, _cc} <- get_recipients(object) do
      Enum.all?(recipients, &valid_recipient?(group, &1))
    else
      _ -> false
    end
  end

  def matches_privacy?(_group, _object), do: false

  defp valid_recipient?(%Group{privacy: "public"}, _recipient), do: true
  defp valid_recipient?(%Group{ap_id: address}, address), do: true
  defp valid_recipient?(%Group{} = group, recipient), do: Group.is_member?(group, recipient)
  defp valid_recipient?(_group, _recipient), do: false

  defp get_recipients(object) when is_map(object) do
    to = Map.get(object, "to", [])
    cc = Map.get(object, "cc", [])
    bcc = Map.get(object, "bcc", [])
    recipients = Enum.concat([to, cc, bcc]) |> Enum.uniq()
    {recipients, to, cc}
  end

  def is_members_only?(object) do
    with %Object{data: data} = object <- Object.normalize(object),
         %Group{privacy: "members_only"} = group <- Group.get_object_group(object) do
      matches_privacy?(group, data)
    else
      _ -> false
    end
  end
end
