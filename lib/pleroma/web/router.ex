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

  pipeline :http_signature do
    plug(Pleroma.Web.Plugs.HTTPSignaturePlug)
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
    pipe_through(:admin_api)

    get("/reports", AdminAPIController, :list_reports)
    get("/reports/:id", AdminAPIController, :report_show)
    put("/reports/:id", AdminAPIController, :report_update_state)
    post("/reports/:id/respond", AdminAPIController, :report_respond)

    post("/users/follow", AdminAPIController, :user_follow)
    post("/users/unfollow", AdminAPIController, :user_unfollow)

    delete("/users", AdminAPIController, :user_delete)
    post("/users", AdminAPIController, :users_create)
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

    get("/config", AdminAPIController, :config_show)
    post("/config", AdminAPIController, :config_update)
    get("/config/migrate_to_db", AdminAPIController, :migrate_to_db)
    get("/config/migrate_from_db", AdminAPIController, :migrate_from_db)

    get("/moderation_log", AdminAPIController, :list_log)

    get("/users/:nickname/statuses", AdminAPIController, :list_user_statuses)
    put("/statuses/:id", AdminAPIController, :status_update)
    delete("/statuses/:id", AdminAPIController, :status_delete)
  end

  scope "/", Pleroma.Web.TwitterAPI do
    pipe_through(:pleroma_html)

    post("/main/ostatus", UtilController, :remote_subscribe)
    get("/ostatus_subscribe", UtilController, :remote_follow)
    post("/ostatus_subscribe", UtilController, :do_remote_follow)
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through(:authenticated_api)

    post("/change_email", UtilController, :change_email)
    post("/change_password", UtilController, :change_password)
    post("/delete_account", UtilController, :delete_account)
    put("/notification_settings", UtilController, :update_notificaton_settings)
    post("/disable_account", UtilController, :disable_account)

    post("/blocks_import", UtilController, :blocks_import)
    post("/follow_import", UtilController, :follow_import)
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

  scope "/api/v1/pleroma", Pleroma.Web.PleromaAPI do
    pipe_through(:authenticated_api)

    get("/conversations/:id/statuses", PleromaAPIController, :conversation_statuses)
    get("/conversations/:id", PleromaAPIController, :conversation)
    patch("/conversations/:id", PleromaAPIController, :update_conversation)
    post("/notifications/read", PleromaAPIController, :read_notification)
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through(:authenticated_api)

    get("/blocks", MastodonAPIController, :blocks)
    get("/mutes", MastodonAPIController, :mutes)
    get("/domain_blocks", MastodonAPIController, :domain_blocks)

    get("/accounts/:id/lists", MastodonAPIController, :account_lists)
    get("/lists", ListController, :index)
    get("/lists/:id", ListController, :show)
    get("/lists/:id/accounts", ListController, :list_accounts)

    post("/notifications/clear", MastodonAPIController, :clear_notifications)
    post("/notifications/dismiss", MastodonAPIController, :dismiss_notification)
    get("/notifications", MastodonAPIController, :notifications)
    get("/notifications/:id", MastodonAPIController, :get_notification)

    delete(
      "/notifications/destroy_multiple",
      MastodonAPIController,
      :destroy_multiple_notifications
    )

    # Note: not present in Mastodon
    get("/bookmarks", MastodonAPIController, :bookmarks)

    get("/accounts/:id/identity_proofs", MastodonAPIController, :empty_array)

    get("/favourites", MastodonAPIController, :favourites)

    get("/accounts/relationships", MastodonAPIController, :relationships)

    get("/accounts/verify_credentials", MastodonAPIController, :verify_credentials)

    get("/timelines/home", MastodonAPIController, :home_timeline)
    get("/timelines/direct", MastodonAPIController, :dm_timeline)

    get("/suggestions", MastodonAPIController, :suggestions)
    get("/scheduled_statuses", MastodonAPIController, :scheduled_statuses)
    get("/scheduled_statuses/:id", MastodonAPIController, :show_scheduled_status)
    get("/follow_requests", MastodonAPIController, :follow_requests)
    get("/filters", MastodonAPIController, :get_filters)
    get("/endorsements", MastodonAPIController, :endorsements)
    get("/conversations", MastodonAPIController, :conversations)
    post("/conversations/:id/read", MastodonAPIController, :conversation_read)

    delete("/lists/:id", ListController, :delete)
    post("/lists", ListController, :create)
    put("/lists/:id", ListController, :update)

    post("/lists/:id/accounts", ListController, :add_to_list)
    delete("/lists/:id/accounts", ListController, :remove_from_list)

    post("/reports", MastodonAPIController, :create_report)

    patch("/pleroma/accounts/update_avatar", MastodonAPIController, :update_avatar)
    patch("/pleroma/accounts/update_banner", MastodonAPIController, :update_banner)
    patch("/pleroma/accounts/update_background", MastodonAPIController, :update_background)

    get("/pleroma/mascot", MastodonAPIController, :get_mascot)
    put("/pleroma/mascot", MastodonAPIController, :set_mascot)

    post("/media", MastodonAPIController, :upload)
    put("/media/:id", MastodonAPIController, :update_media)

    patch("/accounts/update_credentials", MastodonAPIController, :update_credentials)

    post("/polls/:id/votes", MastodonAPIController, :poll_vote)

    post("/statuses/:id/reblog", MastodonAPIController, :reblog_status)
    post("/statuses/:id/unreblog", MastodonAPIController, :unreblog_status)

    post("/statuses/:id/pin", MastodonAPIController, :pin_status)
    post("/statuses/:id/unpin", MastodonAPIController, :unpin_status)

    post("/statuses/:id/mute", MastodonAPIController, :mute_conversation)
    post("/statuses/:id/unmute", MastodonAPIController, :unmute_conversation)

    post("/statuses/:id/favourite", MastodonAPIController, :fav_status)
    post("/statuses/:id/unfavourite", MastodonAPIController, :unfav_status)

    post("/statuses", MastodonAPIController, :post_status)
    delete("/statuses/:id", MastodonAPIController, :delete_status)

    put("/scheduled_statuses/:id", MastodonAPIController, :update_scheduled_status)
    delete("/scheduled_statuses/:id", MastodonAPIController, :delete_scheduled_status)

    post("/filters", MastodonAPIController, :create_filter)
    get("/filters/:id", MastodonAPIController, :get_filter)
    put("/filters/:id", MastodonAPIController, :update_filter)
    delete("/filters/:id", MastodonAPIController, :delete_filter)

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

    post("/push/subscription", SubscriptionController, :create)
    get("/push/subscription", SubscriptionController, :get)
    put("/push/subscription", SubscriptionController, :update)
    delete("/push/subscription", SubscriptionController, :delete)

    # Note: not present in Mastodon: bookmark, unbookmark
    post("/statuses/:id/bookmark", MastodonAPIController, :bookmark_status)
    post("/statuses/:id/unbookmark", MastodonAPIController, :unbookmark_status)
  end

  scope "/api/web", Pleroma.Web.MastodonAPI do
    pipe_through(:authenticated_api)

    put("/settings", MastodonAPIController, :put_settings)
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through(:api)

    get("/instance", MastodonAPIController, :masto_instance)
    get("/instance/peers", MastodonAPIController, :peers)

    post("/apps", MastodonAPIController, :create_app)
    get("/apps/verify_credentials", MastodonAPIController, :verify_app_credentials)

    get("/custom_emojis", MastodonAPIController, :custom_emojis)

    get("/trends", MastodonAPIController, :empty_array)

    get("/accounts/search", SearchController, :account_search)

    get("/timelines/public", MastodonAPIController, :public_timeline)
    get("/timelines/tag/:tag", MastodonAPIController, :hashtag_timeline)
    get("/timelines/list/:list_id", MastodonAPIController, :list_timeline)

    get("/polls/:id", MastodonAPIController, :get_poll)

    post("/accounts", MastodonAPIController, :account_register)
    get("/accounts/:id", MastodonAPIController, :user)
    get("/accounts/:id/followers", MastodonAPIController, :followers)
    get("/accounts/:id/following", MastodonAPIController, :following)
    get("/accounts/:id/statuses", MastodonAPIController, :user_statuses)

    get("/search", SearchController, :search)

    get("/statuses", MastodonAPIController, :get_statuses)
    get("/statuses/:id", MastodonAPIController, :get_status)
    get("/statuses/:id/context", MastodonAPIController, :get_context)
    get("/statuses/:id/card", MastodonAPIController, :status_card)
    get("/statuses/:id/favourited_by", MastodonAPIController, :favourited_by)
    get("/statuses/:id/reblogged_by", MastodonAPIController, :reblogged_by)

    get("/pleroma/accounts/:id/favourites", MastodonAPIController, :user_favourites)

    post(
      "/pleroma/accounts/confirmation_resend",
      MastodonAPIController,
      :account_confirmation_resend
    )
  end

  scope "/api/v2", Pleroma.Web.MastodonAPI do
    pipe_through(:api)
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

    get(
      "/account/confirm_email/:user_id/:token",
      TwitterAPI.Controller,
      :confirm_email,
      as: :confirm_email
    )
  end

  scope "/api", Pleroma.Web, as: :authenticated_twitter_api do
    pipe_through(:authenticated_api)

    get("/oauth_tokens", TwitterAPI.Controller, :oauth_tokens)
    delete("/oauth_tokens/:id", TwitterAPI.Controller, :revoke_token)
    post("/qvitter/statuses/notifications/read", TwitterAPI.Controller, :notifications_read)
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

    get("/mailer/unsubscribe/:token", Mailer.SubscriptionController, :unsubscribe)
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

    get("/api/ap/whoami", ActivityPubController, :whoami)
    get("/users/:nickname/inbox", ActivityPubController, :read_inbox)
    post("/users/:nickname/outbox", ActivityPubController, :update_outbox)
    get("/users/:nickname/followers", ActivityPubController, :followers)
    get("/users/:nickname/following", ActivityPubController, :following)
  end

  scope "/", Pleroma.Web.ActivityPub do
    pipe_through(:activitypub)

    post("/inbox", ActivityPubController, :inbox)
    post("/users/:nickname/inbox", ActivityPubController, :inbox)
  end

  scope "/relay", Pleroma.Web.ActivityPub do
    pipe_through(:ap_service_actor)

    get("/", ActivityPubController, :relay)

    scope [] do
      pipe_through(:http_signature)
      post("/inbox", ActivityPubController, :inbox)
    end

    get("/following", ActivityPubController, :following, assigns: %{relay: true})
    get("/followers", ActivityPubController, :followers, assigns: %{relay: true})
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

    get("/web/*path", MastodonAPIController, :index)
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
