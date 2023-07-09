# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AppController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(OAuthScopesPlug, %{scopes: ["follow", "read"]} when action in [:index])

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaAppOperation

  @doc "GET /api/v1/pleroma/apps"
  def index(%{assigns: %{user: user}} = conn, _params) do
    with apps <- App.get_user_apps(user) do
      render(conn, "index.json", %{apps: apps})
    end
  end
end
