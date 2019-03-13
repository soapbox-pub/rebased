# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ControllerHelper do
  use Pleroma.Web, :controller

  def oauth_scopes(params, default) do
    # Note: `scopes` is used by Mastodon — supporting it but sticking to
    # OAuth's standard `scope` wherever we control it
    Pleroma.Web.OAuth.parse_scopes(params["scope"] || params["scopes"], default)
  end

  def json_response(conn, status, json) do
    conn
    |> put_status(status)
    |> json(json)
  end
end
