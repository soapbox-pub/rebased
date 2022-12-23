# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# A test controller reachable only in :test env.
defmodule Pleroma.Tests.AuthTestController do
  @moduledoc false

  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  # Serves only with proper OAuth token (:api and :authenticated_api)
  # Skipping EnsurePublicOrAuthenticatedPlug has no effect in this case
  #
  # Suggested use case: all :authenticated_api endpoints (makes no sense for :api endpoints)
  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :do_oauth_check)

  # Via :api, keeps :user if token has requested scopes (if :user is dropped, serves if public)
  # Via :authenticated_api, serves if token is present and has requested scopes
  #
  # Suggested use case: vast majority of :api endpoints (no sense for :authenticated_api ones)
  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], fallback: :proceed_unauthenticated}
    when action == :fallback_oauth_check
  )

  # Keeps :user if present, executes regardless of token / token scopes
  # Fails with no :user for :authenticated_api / no user for :api on private instance
  # Note: EnsurePublicOrAuthenticatedPlug is not skipped (private instance fails on no :user)
  # Note: Basic Auth processing results in :skip_plug call for OAuthScopesPlug
  #
  # Suggested use: suppressing OAuth checks for other auth mechanisms (like Basic Auth)
  # For controller-level use, see :skip_oauth_skip_publicity_check instead
  plug(
    :skip_plug,
    OAuthScopesPlug when action == :skip_oauth_check
  )

  # (Shouldn't be executed since the plug is skipped)
  plug(OAuthScopesPlug, %{scopes: ["admin"]} when action == :skip_oauth_check)

  # Via :api, keeps :user if token has requested scopes, and continues with nil :user otherwise
  # Via :authenticated_api, serves if token is present and has requested scopes
  #
  # Suggested use: as :fallback_oauth_check but open with nil :user for :api on private instances
  plug(:skip_public_check when action == :fallback_oauth_skip_publicity_check)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], fallback: :proceed_unauthenticated}
    when action == :fallback_oauth_skip_publicity_check
  )

  # Via :api, keeps :user if present, serves regardless of token presence / scopes / :user presence
  # Via :authenticated_api, serves if :user is set (regardless of token presence and its scopes)
  #
  # Suggested use: making an :api endpoint always accessible (e.g. email confirmation endpoint)
  plug(:skip_auth when action == :skip_oauth_skip_publicity_check)

  # Via :authenticated_api, always fails with 403 (endpoint is insecure)
  # Via :api, drops :user if present and serves if public (private instance rejects on no user)
  #
  # Suggested use: none; please define OAuth rules for all :api / :authenticated_api endpoints
  plug(:skip_plug, [] when action == :missing_oauth_check_definition)

  def do_oauth_check(conn, _params), do: conn_state(conn)

  def fallback_oauth_check(conn, _params), do: conn_state(conn)

  def skip_oauth_check(conn, _params), do: conn_state(conn)

  def fallback_oauth_skip_publicity_check(conn, _params), do: conn_state(conn)

  def skip_oauth_skip_publicity_check(conn, _params), do: conn_state(conn)

  def missing_oauth_check_definition(conn, _params), do: conn_state(conn)

  defp conn_state(%{assigns: %{user: %User{} = user}} = conn),
    do: json(conn, %{user_id: user.id})

  defp conn_state(conn), do: json(conn, %{user_id: nil})
end
