# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserIsAdminPlug do
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn

  alias Pleroma.Web.OAuth

  def init(options) do
    options
  end

  def call(%Plug.Conn{assigns: assigns} = conn, _) do
    token = assigns[:token]
    user = assigns[:user]

    cond do
      token && OAuth.Scopes.contains_admin_scopes?(token.scopes) ->
        # Note: checking for _any_ admin scope presence, not necessarily fitting requested action.
        #   Thus, controller must explicitly invoke OAuthScopesPlug to verify scope requirements.
        conn

      user && user.is_admin && !Pleroma.Config.enforce_oauth_admin_scope_usage?() ->
        conn

      true ->
        conn
        |> render_error(:forbidden, "User is not an admin or OAuth admin scope is not granted.")
        |> halt()
    end
  end
end
