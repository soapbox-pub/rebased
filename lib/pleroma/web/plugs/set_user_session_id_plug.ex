# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetUserSessionIdPlug do
  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Web.OAuth.Token

  def init(opts) do
    opts
  end

  def call(%{assigns: %{token: %Token{} = oauth_token}} = conn, _) do
    AuthHelper.put_session_token(conn, oauth_token.token)
  end

  def call(conn, _), do: conn
end
