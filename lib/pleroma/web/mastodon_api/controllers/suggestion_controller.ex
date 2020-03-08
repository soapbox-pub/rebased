# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionController do
  use Pleroma.Web, :controller

  require Logger

  @doc "GET /api/v1/suggestions"
  def index(conn, _) do
    json(conn, [])
  end
end
