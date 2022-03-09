# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.PlugHelper do
  @moduledoc "Pleroma Plug helper"

  @called_plugs_list_id :called_plugs
  def called_plugs_list_id, do: @called_plugs_list_id

  @skipped_plugs_list_id :skipped_plugs
  def skipped_plugs_list_id, do: @skipped_plugs_list_id

  @doc "Returns `true` if specified plug was called."
  def plug_called?(conn, plug_module) do
    contained_in_private_list?(conn, @called_plugs_list_id, plug_module)
  end

  @doc "Returns `true` if specified plug was explicitly marked as skipped."
  def plug_skipped?(conn, plug_module) do
    contained_in_private_list?(conn, @skipped_plugs_list_id, plug_module)
  end

  @doc "Returns `true` if specified plug was either called or explicitly marked as skipped."
  def plug_called_or_skipped?(conn, plug_module) do
    plug_called?(conn, plug_module) || plug_skipped?(conn, plug_module)
  end

  # Appends plug to known list (skipped, called). Intended to be used from within plug code only.
  def append_to_private_list(conn, list_id, value) do
    list = conn.private[list_id] || []
    modified_list = Enum.uniq(list ++ [value])
    Plug.Conn.put_private(conn, list_id, modified_list)
  end

  defp contained_in_private_list?(conn, private_variable, value) do
    list = conn.private[private_variable] || []
    value in list
  end
end
