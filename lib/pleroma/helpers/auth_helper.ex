# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.AuthHelper do
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  import Plug.Conn

  @doc """
  Skips OAuth permissions (scopes) checks, assigns nil `:token`.
  Intended to be used with explicit authentication and only when OAuth token cannot be determined.
  """
  def skip_oauth(conn) do
    conn
    |> assign(:token, nil)
    |> OAuthScopesPlug.skip_plug()
  end

  def drop_auth_info(conn) do
    conn
    |> assign(:user, nil)
    |> assign(:token, nil)
  end
end
