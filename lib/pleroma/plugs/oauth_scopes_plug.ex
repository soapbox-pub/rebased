# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.OAuthScopesPlug do
  import Plug.Conn

  @behaviour Plug

  def init(%{required_scopes: _} = options), do: options

  def call(%Plug.Conn{assigns: assigns} = conn, %{required_scopes: required_scopes}) do
    token = assigns[:token]
    granted_scopes = token && token.scopes

    if is_nil(token) || required_scopes -- granted_scopes == [] do
      conn
    else
      missing_scopes = required_scopes -- granted_scopes
      error_message = "Insufficient permissions: #{Enum.join(missing_scopes, ", ")}."

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: error_message}))
      |> halt()
    end
  end
end
