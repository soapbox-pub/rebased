# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  @moduledoc """
  Contains stubs for unimplemented Mastodon API endpoints.

  Note: instead of routing directly to this controller's action,
    it's preferable to define an action in relevant (non-generic) controller,
    set up OAuth rules for it and call this controller's function from it.
  """

  use Pleroma.Web, :controller

  require Logger

  plug(:skip_auth when action in [:empty_array, :empty_object])

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  def empty_array(conn, _) do
    Logger.debug("Unimplemented, returning an empty array (list)")
    json(conn, [])
  end

  def empty_object(conn, _) do
    Logger.debug("Unimplemented, returning an empty object (map)")
    json(conn, %{})
  end
end
