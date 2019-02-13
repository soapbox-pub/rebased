# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth do
  def parse_scopes(nil) do
    nil
  end

  def parse_scopes(scopes) when is_list(scopes) do
    scopes
  end

  def parse_scopes(scopes) do
    scopes =
      scopes
      |> to_string()
      |> String.trim()

    if scopes == "",
      do: [],
      else: String.split(scopes, [" ", ","])
  end
end
