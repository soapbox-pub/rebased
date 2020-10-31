# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.AuthHelper do
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @doc """
  Skips OAuth permissions (scopes) checks, assigns nil `:token`.
  Intended to be used with explicit authentication and only when OAuth token cannot be determined.
  """
  def skip_oauth(conn) do
    conn
    |> Plug.Conn.assign(:token, nil)
    |> OAuthScopesPlug.skip_plug()
  end
end
