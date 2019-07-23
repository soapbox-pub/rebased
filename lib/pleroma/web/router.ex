# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Router do
  use Pleroma.Web, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
  end

  pipeline :oauth do
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.LegacyAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.UserEnabledPlug)
    plug(Pleroma.Plugs.SetUserSessionIdPlug)
    plug(Pleroma.Plugs.EnsureUserKeyPlug)
    plug(Pleroma.Plugs.IdempotencyPlug)
  end

  pipeline :authenticated_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.LegacyAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.UserEnabledPlug)
    plug(Pleroma.Plugs.SetUserSessionIdPlug)
    plug(Pleroma.Plugs.EnsureAuthenticatedPlug)
    plug(Pleroma.Plugs.IdempotencyPlug)
  end

  pipeline :admin_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.LegacyAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.AdminSecretAuthenticationPlug)
    plug(Pleroma.Plugs.UserEnabledPlug)
    plug(Pleroma.Plugs.SetUserSessionIdPlug)
    plug(Pleroma.Plugs.EnsureAuthenticatedPlug)
    plug(Pleroma.Plugs.UserIsAdminPlug)
    plug(Pleroma.Plugs.IdempotencyPlug)
  end

  pipeline :mastodon_html do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.LegacyAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.UserEnabledPlug)
    plug(Pleroma.Plugs.SetUserSessionIdPlug)
    plug(Pleroma.Plugs.EnsureUserKeyPlug)
  end

  pipeline :pleroma_html do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.EnsureUserKeyPlug)
  end

  pipeline :oauth_read_or_public do
    plug(Pleroma.Plugs.OAuthScopesPlug, %{
      scopes: ["read"],
      fallback: :proceed_unauthenticated
    })

    plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)
  end

  pipeline :oauth_read do
    plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: ["read"]})
  end

  pipeline :oauth_write do
    plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: ["write"]})
  end

  pipeline :oauth_follow do
    plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: ["follow"]})
  end

  pipeline :oauth_push do
    plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: ["push"]})
  end

  pipeline :well_known do
    plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
  end

  pipeline :config do
    plug(:accepts, ["json", "xml"])
  end

  pipeline :pleroma_api do
    plug(:accepts, ["html", "json"])
  end

  pipeline :mailbox_preview do
    plug(:accepts, ["html"])

    plug(:put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' 'unsafe-eval'"
    })
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through(:pleroma_api)

    get("/password_reset/:token", PasswordController, :reset, as: :reset_password)
    post("/password_reset", PasswordController, :do_reset, as: :reset_password)
    get("/emoji", UtilController, :emoji)
    get("/captcha", UtilController, :captcha)
    get("/healthcheck", UtilController, :healthcheck)
  end

  scope "/api/pleroma", Pleroma.Web do
    pipe_through(:pleroma_api)
    post("/uploader_callback/:upload_path", UploaderController, :callback)
  end

  scope "/api/pleroma/admin", Pleroma.Web.AdminAPI do
    pipe_through([:admin_api, :oauth_write])

    post("/users/follow", AdminAPIController, :user_follow)
    post("/users/unfollow", AdminAPIController, :user_unfollow)

    delete("/users", AdminAPIController, :user_delete)
    post("/users", AdminAPIController, :user_create)
    patch("/users/:nickname/toggle_activation", AdminAPIController, :user_toggle_activation)
    put("/users/tag", AdminAPIController, :tag_users)
    delete("/users/tag", AdminAPIController, :untag_users)

    get("/users/:nickname/permission_group", AdminAPIController, :right_get)
    get("/users/:nickname/permission_group/:permission_group", AdminAPIController, :right_get)
    post("/users/:nickname/permission_group/:permission_group", AdminAPIController, :right_add)

    delete(
      "/users/:nickname/permission_group/:permission_group",
      AdminAPIController,
      :right_delete
    )

    put("/users/:nickname/activation_status", AdminAPIController, :set_activation_status)

    post("/relay", AdminAPIController, :relay_follow)
    delete("/relay", AdminAPIController, :relay_unfollow)

    get("/users/invite_token", AdminAPIController, :get_invite_token)
    get("/users/invites", AdminAPIController, :invites)
    post("/users/revoke_invite", AdminAPIController, :revoke_invite)
    post("/users/email_invite", AdminAPIController, :email_invite)

    get("/users/:nickname/password_reset", AdminAPIController, :get_password_reset)

    get("/users", AdminAPIController, :list_users)
    get("/users/:nickname", AdminAPIController, :user_show)

    get("/reports", AdminAPIController, :list_reports)
    get("/reports/:id", AdminAPIController, :report_show)
    put("/reports/:id", AdminAPIController, :report_update_state)
    post("/reports/:id/respond", AdminAPIController, :report_respond)

    put("/statuses/:id", AdminAPIController, :status_update)
    delete("/statuses/:id", AdminAPIController, :status_delete)

    get("/config", AdminAPIController, :config_show)
    post("/config", AdminAPIController, :config_update)
  end

  scope "/", Pleroma.Web.TwitterAPI do
    pipe_through(:pleroma_html)

    post("/main/ostatus", UtilController, :remote_subscribe)
    get("/ostatus_subscribe", UtilController, :remote_follow)

    scope [] do
      pipe_through(:oauth_follow)
      post("/ostatus_subscribe", UtilController, :do_remote_follow)
    end
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through(:authenticated_api)

    scope [] do
      pipe_through(:oauth_write)

      post("/change_password", UtilController, :change_password)
      post("/delete_account", UtilController, :delete_account)
      put("/notification_settings", UtilController, :update_notificaton_settings)
      post("/disable_account", UtilController, :disable_account)
    end

    scope [] do
      pipe_through(:oauth_follow)

      post("/blocks_import", UtilController, :blocks_import)
      post("/follow_import", UtilController, :follow_import)
    end

    scope [] do
      pipe_through(:oauth_read)

      post("/notifications/read", UtilController, :notifications_read)
    end
  end

  scope "/oauth", Pleroma.Web.OAuth do
    scope [] do
      pipe_through(:oauth)
      get("/authorize", OAuthController, :authorize)
    end

    post("/authorize", OAuthController, :create_authorization)
    post("/token", OAuthController, :token_exchange)
    post("/revoke", OAuthController, :token_revoke)
    get("/registration_details", OAuthController, :registration_details)

    scope [] do
      pipe_through(:browser)

      get("/prepare_request", OAuthController, :prepare_request)
      get("/:provider", OAuthController, :request)
      get("/:provider/callback", OAuthController, :callback)
      post("/register", OAuthController, :register)
    end
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through(:authenticated_api)

    scope [] do
      pipe_through(:oauth_read)

      get("/accounts/verify_credentials", MastodonAPIController, :verify_credentials)

      get("/accounts/relationships", MastodonAPIController, :relationships)

      get("/accounts/:id/lists", MastodonAPIController, :account_lists)
      get("/accounts/:id/identity_proofs", MastodonAPIController, :empty_array)

      get("/follow_requests", MastodonAPIController, :follow_requests)
      get("/blocks", MastodonAPIController, :blocks)
      get("/mutes", MastodonAPIController, :mutes)

      get("/timelines/home", MastodonAPIController, :home_timeline)
      get("/timelines/direct", MastodonAPIController, :dm_timeline)

      get("/favourites", MastodonAPIController, :favourites)
      get("/bookmarks", MastodonAPIController, :bookmarks)

      post("/notifications/clear", MastodonAPIController, :clear_notifications)
      post("/notifications/dismiss", MastodonAPIController, :dismiss_notification)
      get("/notifications", MastodonAPIController, :notifications)
      get("/notifications/:id", MastodonAPIController, :get_notification)
      delete("/notifications/destroy_multiple", MastodonAPIController, :destroy_multiple)

      get("/scheduled_statuses", MastodonAPIController, :scheduled_statuses)
      get("/scheduled_statuses/:id", MastodonAPIController, :show_scheduled_status)

      get("/lists", MastodonAPIController, :get_lists)
      get("/lists/:id", MastodonAPIController, :get_list)
      get("/lists/:id/accounts", MastodonAPIController, :list_accounts)

      get("/domain_blocks", MastodonAPIController, :domain_blocks)

      get("/filters", MastodonAPIController, :get_filters)

      get("/suggestions", MastodonAPIController, :suggestions)

      get("/conversations", MastodonAPIController, :conversations)
      post("/conversations/:id/read", MastodonAPIController, :conversation_read)

      get("/endorsements", MastodonAPIController, :empty_array)
    end

    scope [] do
      pipe_through(:oauth_write)

      patch("/accounts/update_credentials", MastodonAPIController, :update_credentials)

      post("/statuses", MastodonAPIController, :post_status)
      delete("/statuses/:id", MastodonAPIController, :delete_status)

      post("/statuses/:id/reblog", MastodonAPIController, :reblog_status)
      post("/statuses/:id/unreblog", MastodonAPIController, :unreblog_status)
      post("/statuses/:id/favourite", MastodonAPIController, :fav_status)
      post("/statuses/:id/unfavourite", MastodonAPIController, :unfav_status)
      post("/statuses/:id/pin", MastodonAPIController, :pin_status)
      post("/statuses/:id/unpin", MastodonAPIController, :unpin_status)
      post("/statuses/:id/bookmark", MastodonAPIController, :bookmark_status)
      post("/statuses/:id/unbookmark", MastodonAPIController, :unbookmark_status)
      post("/statuses/:id/mute", MastodonAPIController, :mute_conversation)
      post("/statuses/:id/unmute", MastodonAPIController, :unmute_conversation)

      put("/scheduled_statuses/:id", MastodonAPIController, :update_scheduled_status)
      delete("/scheduled_statuses/:id", MastodonAPIController, :delete_scheduled_status)

      post("/polls/:id/votes", MastodonAPIController, :poll_vote)

      post("/media", MastodonAPIController, :upload)
      put("/media/:id", MastodonAPIController, :update_media)

      delete("/lists/:id", MastodonAPIController, :delete_list)
      post("/lists", MastodonAPIController, :create_list)
      put("/lists/:id", MastodonAPIController, :rename_list)

      post("/lists/:id/accounts", MastodonAPIController, :add_to_list)
      delete("/lists/:id/accounts", MastodonAPIController, :remove_from_list)

      post("/filters", MastodonAPIController, :create_filter)
      get("/filters/:id", MastodonAPIController, :get_filter)
      put("/filters/:id", MastodonAPIController, :update_filter)
      delete("/filters/:id", MastodonAPIController, :delete_filter)

      patch("/pleroma/accounts/update_avatar", MastodonAPIController, :update_avatar)
      patch("/pleroma/accounts/update_banner", MastodonAPIController, :update_banner)
      patch("/pleroma/accounts/update_background", MastodonAPIController, :update_background)

      get("/pleroma/mascot", MastodonAPIController, :get_mascot)
      put("/pleroma/mascot", MastodonAPIController, :set_mascot)

      post("/reports", MastodonAPIController, :reports)
    end

    scope [] do
      pipe_through(:oauth_follow)

      post("/follows", MastodonAPIController, :follow)
      post("/accounts/:id/follow", MastodonAPIController, :follow)

      post("/accounts/:id/unfollow", MastodonAPIController, :unfollow)
      post("/accounts/:id/block", MastodonAPIController, :block)
      post("/accounts/:id/unblock", MastodonAPIController, :unblock)
      post("/accounts/:id/mute", MastodonAPIController, :mute)
      post("/accounts/:id/unmute", MastodonAPIController, :unmute)

      post("/follow_requests/:id/authorize", MastodonAPIController, :authorize_follow_request)
      post("/follow_requests/:id/reject", MastodonAPIController, :reject_follow_request)

      post("/domain_blocks", MastodonAPIController, :block_domain)
      delete("/domain_blocks", MastodonAPIController, :unblock_domain)

      post("/pleroma/accounts/:id/subscribe", MastodonAPIController, :subscribe)
      post("/pleroma/accounts/:id/unsubscribe", MastodonAPIController, :unsubscribe)
    end

    scope [] do
      pipe_through(:oauth_push)

      post("/push/subscription", SubscriptionController, :create)
      get("/push/subscription", SubscriptionController, :get)
      put("/push/subscription", SubscriptionController, :update)
      delete("/push/subscription", SubscriptionController, :delete)
    end
  end

  scope "/api/web", Pleroma.Web.MastodonAPI do
    pipe_through([:authenticated_api, :oauth_write])

    put("/settings", MastodonAPIController, :put_settings)
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through(:api)

    post("/accounts", MastodonAPIController, :account_register)

    get("/instance", MastodonAPIController, :masto_instance)
    get("/instance/peers", MastodonAPIController, :peers)
    post("/apps", MastodonAPIController, :create_app)
    get("/apps/verify_credentials", MastodonAPIController, :verify_app_credentials)
    get("/custom_emojis", MastodonAPIController, :custom_emojis)

    get("/statuses/:id/card", MastodonAPIController, :status_card)

    get("/statuses/:id/favourited_by", MastodonAPIController, :favourited_by)
    get("/statuses/:id/reblogged_by", MastodonAPIController, :reblogged_by)

    get("/trends", MastodonAPIController, :empty_array)

    get("/accounts/search", SearchController, :account_search)

    scope [] do
      pipe_through(:oauth_read_or_public)

      get("/timelines/public", MastodonAPIController, :public_timeline)
      get("/timelines/tag/:tag", MastodonAPIController, :hashtag_timeline)
      get("/timelines/list/:list_id", MastodonAPIController, :list_timeline)

      get("/statuses/:id", MastodonAPIController, :get_status)
      get("/statuses/:id/context", MastodonAPIController, :get_context)

      get("/polls/:id", MastodonAPIController, :get_poll)

      get("/accounts/:id/statuses", MastodonAPIController, :user_statuses)
      get("/accounts/:id/followers", MastodonAPIController, :followers)
      get("/accounts/:id/following", MastodonAPIController, :following)
      get("/accounts/:id", MastodonAPIController, :user)

      get("/search", SearchController, :search)

      get("/pleroma/accounts/:id/favourites", MastodonAPIController, :user_favourites)
    end
  end

  scope "/api/v2", Pleroma.Web.MastodonAPI do
    pipe_through([:api, :oauth_read_or_public])
    get("/search", SearchController, :search2)
  end

  scope "/api", Pleroma.Web do
    pipe_through(:config)

    get("/help/test", TwitterAPI.UtilController, :help_test)
    post("/help/test", TwitterAPI.UtilController, :help_test)
    get("/statusnet/config", TwitterAPI.UtilController, :config)
    get("/statusnet/version", TwitterAPI.UtilController, :version)
    get("/pleroma/frontend_configurations", TwitterAPI.UtilController, :frontend_configurations)
  end

  scope "/api", Pleroma.Web do
    pipe_through(:api)

    post("/account/register", TwitterAPI.Controller, :register)
    post("/account/password_reset", TwitterAPI.Controller, :password_reset)

    post("/account/resend_confirmation_email", TwitterAPI.Controller, :resend_confirmation_email)

    get(
      "/account/confirm_email/:user_id/:token",
      TwitterAPI.Controller,
      :confirm_email,
      as: :confirm_email
    )

    scope [] do
      pipe_through(:oauth_read_or_public)

      get("/statuses/user_timeline", TwitterAPI.Controller, :user_timeline)
      get("/qvitter/statuses/user_timeline", TwitterAPI.Controller, :user_timeline)
      get("/users/show", TwitterAPI.Controller, :show_user)

      get("/statuses/followers", TwitterAPI.Controller, :followers)
      get("/statuses/friends", TwitterAPI.Controller, :friends)
      get("/statuses/blocks", TwitterAPI.Controller, :blocks)
      get("/statuses/show/:id", TwitterAPI.Controller, :fetch_status)
      get("/statusnet/conversation/:id", TwitterAPI.Controller, :fetch_conversation)

      get("/search", TwitterAPI.Controller, :search)
      get("/statusnet/tags/timeline/:tag", TwitterAPI.Controller, :public_and_external_timeline)
    end
  end

  scope "/api", Pleroma.Web do
    pipe_through([:api, :oauth_read_or_public])

    get("/statuses/public_timeline", TwitterAPI.Controller, :public_timeline)

    get(
      "/statuses/public_and_external_timeline",
      TwitterAPI.Controller,
      :public_and_external_timeline
    )

    get("/statuses/networkpublic_timeline", TwitterAPI.Controller, :public_and_external_timeline)
  end

  scope "/api", Pleroma.Web, as: :twitter_api_search do
    pipe_through([:api, :oauth_read_or_public])
    get("/pleroma/search_user", TwitterAPI.Controller, :search_user)
  end

  scope "/api", Pleroma.Web, as: :authenticated_twitter_api do
    pipe_through(:authenticated_api)

    get("/oauth_tokens", TwitterAPI.Controller, :oauth_tokens)
    delete("/oauth_tokens/:id", TwitterAPI.Controller, :revoke_token)

    scope [] do
      pipe_through(:oauth_read)

      get("/account/verify_credentials", TwitterAPI.Controller, :verify_credentials)
      post("/account/verify_credentials", TwitterAPI.Controller, :verify_credentials)

      get("/statuses/home_timeline", TwitterAPI.Controller, :friends_timeline)
      get("/statuses/friends_timeline", TwitterAPI.Controller, :friends_timeline)
      get("/statuses/mentions", TwitterAPI.Controller, :mentions_timeline)
      get("/statuses/mentions_timeline", TwitterAPI.Controller, :mentions_timeline)
      get("/statuses/dm_timeline", TwitterAPI.Controller, :dm_timeline)
      get("/qvitter/statuses/notifications", TwitterAPI.Controller, :notifications)

      get("/pleroma/friend_requests", TwitterAPI.Controller, :friend_requests)

      get("/friends/ids", TwitterAPI.Controller, :friends_ids)
      get("/friendships/no_retweets/ids", TwitterAPI.Controller, :empty_array)

      get("/mutes/users/ids", TwitterAPI.Controller, :empty_array)
      get("/qvitter/mutes", TwitterAPI.Controller, :raw_empty_array)

      get("/externalprofile/show", TwitterAPI.Controller, :external_profile)

      post("/qvitter/statuses/notifications/read", TwitterAPI.Controller, :notifications_read)
    end

    scope [] do
      pipe_through(:oauth_write)

      post("/account/update_profile", TwitterAPI.Controller, :update_profile)
      post("/account/update_profile_banner", TwitterAPI.Controller, :update_banner)
      post("/qvitter/update_background_image", TwitterAPI.Controller, :update_background)

      post("/statuses/update", TwitterAPI.Controller, :status_update)
      post("/statuses/retweet/:id", TwitterAPI.Controller, :retweet)
      post("/statuses/unretweet/:id", TwitterAPI.Controller, :unretweet)
      post("/statuses/destroy/:id", TwitterAPI.Controller, :delete_post)

      post("/statuses/pin/:id", TwitterAPI.Controller, :pin)
      post("/statuses/unpin/:id", TwitterAPI.Controller, :unpin)

      post("/statusnet/media/upload", TwitterAPI.Controller, :upload)
      post("/media/upload", TwitterAPI.Controller, :upload_json)
      post("/media/metadata/create", TwitterAPI.Controller, :update_media)

      post("/favorites/create/:id", TwitterAPI.Controller, :favorite)
      post("/favorites/create", TwitterAPI.Controller, :favorite)
      post("/favorites/destroy/:id", TwitterAPI.Controller, :unfavorite)

      post("/qvitter/update_avatar", TwitterAPI.Controller, :update_avatar)
    end

    scope [] do
      pipe_through(:oauth_follow)

      post("/pleroma/friendships/approve", TwitterAPI.Controller, :approve_friend_request)
      post("/pleroma/friendships/deny", TwitterAPI.Controller, :deny_friend_request)

      post("/friendships/create", TwitterAPI.Controller, :follow)
      post("/friendships/destroy", TwitterAPI.Controller, :unfollow)

      post("/blocks/create", TwitterAPI.Controller, :block)
      post("/blocks/destroy", TwitterAPI.Controller, :unblock)
    end
  end

  pipeline :ap_service_actor do
    plug(:accepts, ["activity+json", "json"])
  end

  pipeline :ostatus do
    plug(:accepts, ["html", "xml", "atom", "activity+json", "json"])
  end

  pipeline :oembed do
    plug(:accepts, ["json", "xml"])
  end

  scope "/", Pleroma.Web do
    pipe_through(:ostatus)

    get("/objects/:uuid", OStatus.OStatusController, :object)
    get("/activities/:uuid", OStatus.OStatusController, :activity)
    get("/notice/:id", OStatus.OStatusController, :notice)
    get("/notice/:id/embed_player", OStatus.OStatusController, :notice_player)
    get("/users/:nickname/feed", OStatus.OStatusController, :feed)
    get("/users/:nickname", OStatus.OStatusController, :feed_redirect)

    post("/users/:nickname/salmon", OStatus.OStatusController, :salmon_incoming)
    post("/push/hub/:nickname", Websub.WebsubController, :websub_subscription_request)
    get("/push/subscriptions/:id", Websub.WebsubController, :websub_subscription_confirmation)
    post("/push/subscriptions/:id", Websub.WebsubController, :websub_incoming)
  end

  pipeline :activitypub do
    plug(:accepts, ["activity+json", "json"])
    plug(Pleroma.Web.Plugs.HTTPSignaturePlug)
    plug(Pleroma.Web.Plugs.MappedSignatureToIdentityPlug)
  end

  scope "/", Pleroma.Web.ActivityPub do
    # XXX: not really ostatus
    pipe_through(:ostatus)

    get("/users/:nickname/outbox", ActivityPubController, :outbox)
    get("/objects/:uuid/likes", ActivityPubController, :object_likes)
  end

  pipeline :activitypub_client do
    plug(:accepts, ["activity+json", "json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.BasicAuthDecoderPlug)
    plug(Pleroma.Plugs.UserFetcherPlug)
    plug(Pleroma.Plugs.SessionAuthenticationPlug)
    plug(Pleroma.Plugs.LegacyAuthenticationPlug)
    plug(Pleroma.Plugs.AuthenticationPlug)
    plug(Pleroma.Plugs.UserEnabledPlug)
    plug(Pleroma.Plugs.SetUserSessionIdPlug)
    plug(Pleroma.Plugs.EnsureUserKeyPlug)
  end

  scope "/", Pleroma.Web.ActivityPub do
    pipe_through([:activitypub_client])

    scope [] do
      pipe_through(:oauth_read)
      get("/api/ap/whoami", ActivityPubController, :whoami)
      get("/users/:nickname/inbox", ActivityPubController, :read_inbox)
    end

    scope [] do
      pipe_through(:oauth_write)
      post("/users/:nickname/outbox", ActivityPubController, :update_outbox)
    end

    scope [] do
      pipe_through(:oauth_read_or_public)
      get("/users/:nickname/followers", ActivityPubController, :followers)
      get("/users/:nickname/following", ActivityPubController, :following)
    end
  end

  scope "/", Pleroma.Web.ActivityPub do
    pipe_through(:activitypub)
    post("/inbox", ActivityPubController, :inbox)
    post("/users/:nickname/inbox", ActivityPubController, :inbox)
  end

  scope "/relay", Pleroma.Web.ActivityPub do
    pipe_through(:ap_service_actor)

    get("/", ActivityPubController, :relay)
    post("/inbox", ActivityPubController, :inbox)
  end

  scope "/internal/fetch", Pleroma.Web.ActivityPub do
    pipe_through(:ap_service_actor)

    get("/", ActivityPubController, :internal_fetch)
    post("/inbox", ActivityPubController, :inbox)
  end

  scope "/.well-known", Pleroma.Web do
    pipe_through(:well_known)

    get("/host-meta", WebFinger.WebFingerController, :host_meta)
    get("/webfinger", WebFinger.WebFingerController, :webfinger)
    get("/nodeinfo", Nodeinfo.NodeinfoController, :schemas)
  end

  scope "/nodeinfo", Pleroma.Web do
    get("/:version", Nodeinfo.NodeinfoController, :nodeinfo)
  end

  scope "/", Pleroma.Web.MastodonAPI do
    pipe_through(:mastodon_html)

    get("/web/login", MastodonAPIController, :login)
    delete("/auth/sign_out", MastodonAPIController, :logout)

    post("/auth/password", MastodonAPIController, :password_reset)

    scope [] do
      pipe_through(:oauth_read_or_public)
      get("/web/*path", MastodonAPIController, :index)
    end
  end

  pipeline :remote_media do
  end

  scope "/proxy/", Pleroma.Web.MediaProxy do
    pipe_through(:remote_media)

    get("/:sig/:url", MediaProxyController, :remote)
    get("/:sig/:url/:filename", MediaProxyController, :remote)
  end

  if Pleroma.Config.get(:env) == :dev do
    scope "/dev" do
      pipe_through([:mailbox_preview])

      forward("/mailbox", Plug.Swoosh.MailboxPreview, base_path: "/dev/mailbox")
    end
  end

  scope "/", Pleroma.Web.MongooseIM do
    get("/user_exists", MongooseIMController, :user_exists)
    get("/check_password", MongooseIMController, :check_password)
  end

  scope "/", Fallback do
    get("/registration/:token", RedirectController, :registration_page)
    get("/:maybe_nickname_or_id", RedirectController, :redirector_with_meta)
    get("/api*path", RedirectController, :api_not_implemented)
    get("/*path", RedirectController, :redirector)

    options("/*path", RedirectController, :empty)
  end
end

defmodule Fallback.RedirectController do
  use Pleroma.Web, :controller
  require Logger
  alias Pleroma.User
  alias Pleroma.Web.Metadata

  def api_not_implemented(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{error: "Not implemented"})
  end

  def redirector(conn, _params, code \\ 200) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(code, index_file_path())
  end

  def redirector_with_meta(conn, %{"maybe_nickname_or_id" => maybe_nickname_or_id} = params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(maybe_nickname_or_id) do
      redirector_with_meta(conn, %{user: user})
    else
      nil ->
        redirector(conn, params)
    end
  end

  def redirector_with_meta(conn, params) do
    {:ok, index_content} = File.read(index_file_path())

    tags =
      try do
        Metadata.build_tags(params)
      rescue
        e ->
          Logger.error(
            "Metadata rendering for #{conn.request_path} failed.\n" <>
              Exception.format(:error, e, __STACKTRACE__)
          )

          ""
      end

    response = String.replace(index_content, "<!--server-generated-meta-->", tags)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, response)
  end

  def index_file_path do
    Pleroma.Plugs.InstanceStatic.file_path("index.html")
  end

  def registration_page(conn, params) do
    redirector(conn, params)
  end

  def empty(conn, _params) do
    conn
    |> put_status(204)
    |> text("")
  end
end
