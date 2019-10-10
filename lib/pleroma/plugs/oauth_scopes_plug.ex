# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.OAuthScopesPlug do
  import Plug.Conn
  import Pleroma.Web.Gettext

  alias Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug

  @behaviour Plug

  def init(%{scopes: _} = options), do: options

  def call(%Plug.Conn{assigns: assigns} = conn, %{scopes: scopes} = options) do
    op = options[:op] || :|
    token = assigns[:token]
    matched_scopes = token && filter_descendants(scopes, token.scopes)

    cond do
      is_nil(token) ->
        maybe_perform_instance_privacy_check(conn, options)

      op == :| && Enum.any?(matched_scopes) ->
        conn

      op == :& && matched_scopes == scopes ->
        conn

      options[:fallback] == :proceed_unauthenticated ->
        conn
        |> assign(:user, nil)
        |> assign(:token, nil)
        |> maybe_perform_instance_privacy_check(options)

      true ->
        missing_scopes = scopes -- matched_scopes
        permissions = Enum.join(missing_scopes, " #{op} ")

        error_message =
          dgettext("errors", "Insufficient permissions: %{permissions}.", permissions: permissions)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:forbidden, Jason.encode!(%{error: error_message}))
        |> halt()
    end
  end

  @doc "Filters descendants of supported scopes"
  def filter_descendants(scopes, supported_scopes) do
    Enum.filter(
      scopes,
      fn scope ->
        Enum.find(
          supported_scopes,
          &(scope == &1 || String.starts_with?(scope, &1 <> ":"))
        )
      end
    )
  end

  defp maybe_perform_instance_privacy_check(%Plug.Conn{} = conn, options) do
    if options[:skip_instance_privacy_check] do
      conn
    else
      EnsurePublicOrAuthenticatedPlug.call(conn, [])
    end
  end
end
