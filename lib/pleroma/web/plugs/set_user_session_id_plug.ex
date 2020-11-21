# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetUserSessionIdPlug do
  import Plug.Conn

  alias Pleroma.Web.OAuth.Token

  def init(opts) do
    opts
  end

  def call(%{assigns: %{token: %Token{} = oauth_token}} = conn, _) do
    put_session(conn, :oauth_token, oauth_token.token)
  end

  def call(conn, _), do: conn
end
