# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.ExpectAuthenticatedCheckPlug do
  @moduledoc """
  Marks `Pleroma.Web.Plugs.EnsureAuthenticatedPlug` as expected to be executed later in plug chain.

  No-op plug which affects `Pleroma.Web` operation (is checked with `PlugHelper.plug_called?/2`).
  """

  use Pleroma.Web, :plug

  def init(options), do: options

  @impl true
  def perform(conn, _) do
    conn
  end
end
