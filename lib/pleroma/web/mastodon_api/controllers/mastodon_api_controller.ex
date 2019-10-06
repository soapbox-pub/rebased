# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Plugs.OAuthScopesPlug
  @unauthenticated_access %{fallback: :proceed_unauthenticated, scopes: []}

  # Note: :index action handles attempt of unauthenticated access to private instance with redirect
  plug(
    OAuthScopesPlug,
    Map.merge(@unauthenticated_access, %{scopes: ["read"], skip_instance_privacy_check: true})
    when action == :index
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"]} when action in [:suggestions, :verify_app_credentials]
  )

  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action == :put_settings)

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:statuses"]} when action == :get_poll
  )

  plug(OAuthScopesPlug, %{scopes: ["write:statuses"]} when action == :poll_vote)

  plug(OAuthScopesPlug, %{scopes: ["read:favourites"]} when action == :favourites)

  plug(OAuthScopesPlug, %{scopes: ["write:media"]} when action in [:upload, :update_media])

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "read:blocks"]} when action == :blocks
  )

  # To do: POST /api/v1/follows is not present in Mastodon; consider removing the action
  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]} when action == :follows
  )

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:mutes"]} when action == :mutes)

  # Note: scope not present in Mastodon: read:bookmarks
  plug(OAuthScopesPlug, %{scopes: ["read:bookmarks"]} when action == :bookmarks)

  # An extra safety measure for possible actions not guarded by OAuth permissions specification
  plug(
    Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug
    when action not in [
           :create_app,
           :index,
           :login,
           :logout,
           :password_reset,
           :masto_instance,
           :peers,
           :custom_emojis
         ]
  )

  plug(RateLimiter, :password_reset when action == :password_reset)

  @local_mastodon_name "Mastodon-Local"

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  # Stubs for unimplemented mastodon api
  #
  def empty_array(conn, _) do
    Logger.debug("Unimplemented, returning an empty array")
    json(conn, [])
  end

  def empty_object(conn, _) do
    Logger.debug("Unimplemented, returning an empty object")
    json(conn, %{})
  end
end
