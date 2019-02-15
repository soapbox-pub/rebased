# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.OAuthScopesPlug do
  import Plug.Conn

  @behaviour Plug

  def init(%{scopes: _} = options), do: options

  def call(%Plug.Conn{assigns: assigns} = conn, %{scopes: scopes} = options) do
    op = options[:op] || :|
    token = assigns[:token]

    cond do
      is_nil(token) ->
        conn

      op == :| && scopes -- token.scopes != scopes ->
        conn

      op == :& && scopes -- token.scopes == [] ->
        conn

      options[:fallback] == :proceed_unauthenticated ->
        conn
        |> assign(:user, nil)
        |> assign(:token, nil)

      true ->
        missing_scopes = scopes -- token.scopes
        error_message = "Insufficient permissions: #{Enum.join(missing_scopes, " #{op} ")}."

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: error_message}))
        |> halt()
    end
  end
end
