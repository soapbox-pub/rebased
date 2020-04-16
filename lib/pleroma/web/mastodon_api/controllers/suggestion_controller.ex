# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionController do
  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug

  require Logger

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :index)

  @doc "GET /api/v1/suggestions"
  def index(conn, params),
    do: Pleroma.Web.MastodonAPI.MastodonAPIController.empty_array(conn, params)
end
