# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.PlugHelper do
  @moduledoc "Pleroma Plug helper"

  def append_to_called_plugs(conn, plug_module) do
    append_to_private_list(conn, :called_plugs, plug_module)
  end

  def append_to_skipped_plugs(conn, plug_module) do
    append_to_private_list(conn, :skipped_plugs, plug_module)
  end

  def plug_called?(conn, plug_module) do
    contained_in_private_list?(conn, :called_plugs, plug_module)
  end

  def plug_skipped?(conn, plug_module) do
    contained_in_private_list?(conn, :skipped_plugs, plug_module)
  end

  def plug_called_or_skipped?(conn, plug_module) do
    plug_called?(conn, plug_module) || plug_skipped?(conn, plug_module)
  end

  defp append_to_private_list(conn, private_variable, value) do
    list = conn.private[private_variable] || []
    modified_list = Enum.uniq(list ++ [value])
    Plug.Conn.put_private(conn, private_variable, modified_list)
  end

  defp contained_in_private_list?(conn, private_variable, value) do
    list = conn.private[private_variable] || []
    value in list
  end
end
