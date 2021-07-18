# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Utils.Guards do
  @moduledoc """
  Project-wide custom guards.
  See: https://hexdocs.pm/elixir/master/patterns-and-guards.html#custom-patterns-and-guards-expressions
  """

  @doc "Checks for non-empty string"
  defguard not_empty_string(string) when is_binary(string) and string != ""
end
