# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth do
  def parse_scopes(scopes, _default) when is_list(scopes) do
    Enum.filter(scopes, &(&1 not in [nil, ""]))
  end

  def parse_scopes(scopes, default) when is_binary(scopes) do
    scopes
    |> String.trim()
    |> String.split(~r/[\s,]+/)
    |> parse_scopes(default)
  end

  def parse_scopes(_, default) do
    default
  end
end
