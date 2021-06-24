# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group.Privacy do
  @moduledoc """
  Validate that ActivityPub objects match a group's privacy settings.
  """
  alias Pleroma.Group

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

  defp get_recipients(data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    recipients = Enum.concat([to, cc, bcc])
    {recipients, to, cc}
  end
end
