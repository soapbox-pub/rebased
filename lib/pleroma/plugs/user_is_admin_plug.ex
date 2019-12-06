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

  unless Pleroma.Config.enforce_oauth_admin_scope_usage?() do
    # To do: once AdminFE makes use of "admin" scope, disable the following func definition
    #   (fail on no admin scope(s) in token even if `is_admin` is true)
    def call(%Plug.Conn{assigns: %{user: %Pleroma.User{is_admin: true}}} = conn, _) do
      conn
    end
  end

  def call(%Plug.Conn{assigns: %{token: %OAuth.Token{scopes: oauth_scopes} = _token}} = conn, _) do
    if OAuth.Scopes.contains_admin_scopes?(oauth_scopes) do
      # Note: checking for _any_ admin scope presence, not necessarily fitting requested action.
      #   Thus, controller must explicitly invoke OAuthScopesPlug to verify scope requirements.
      conn
    else
      fail(conn)
    end
  end

  def call(conn, _) do
    fail(conn)
  end

  defp fail(conn) do
    conn
    |> render_error(:forbidden, "User is not an admin or OAuth admin scope is not granted.")
    |> halt()
  end
end
