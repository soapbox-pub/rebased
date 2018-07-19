defmodule Pleroma.Web.Router do
  use Pleroma.Web, :router

  alias Pleroma.{Repo, User, Web.Router}

  @instance Application.get_env(:pleroma, :instance)
  @federating Keyword.get(@instance, :federating)
  @public Keyword.get(@instance, :public)
  @registrations_open Keyword.get(@instance, :registrations_open)

  def user_fetcher(username) do
    {:ok, Repo.get_by(User, %{nickname: username})}
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1, optional: true})
  end

  pipeline :authenticated_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1})
  end

  pipeline :mastodon_html do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1, optional: true})
  end

  pipeline :pleroma_html do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(Pleroma.Plugs.OAuthPlug)
    plug(Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1, optional: true})
  end

  pipeline :well_known do
    plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
  end

  pipeline :config do
    plug(:accepts, ["json", "xml"])
  end

  pipeline :oauth do
    plug(:accepts, ["html", "json"])
  end

  pipeline :pleroma_api do
    plug(:accepts, ["html", "json"])
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through(:pleroma_api)
    get("/password_reset/:token", UtilController, :show_password_reset)
    post("/password_reset", UtilController, :password_reset)
    get("/emoji", UtilController, :emoji)
  end

  scope "/", Pleroma.Web.TwitterAPI do
    pipe_through(:pleroma_html)
    get("/ostatus_subscribe", UtilController, :remote_follow)
    post("/ostatus_subscribe", UtilController, :do_remote_follow)
    post("/main/ostatus", UtilController, :remote_subscribe)
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through(:authenticated_api)
    post("/follow_import", UtilController, :follow_import)
    post("/change_password", UtilController, :change_password)
    post("/delete_account", UtilController, :delete_account)
  end

  scope "/oauth", Pleroma.Web.OAuth do
    get("/authorize", OAuthController, :authorize)
    post("/authorize", OAuthController, :create_authorization)
    post("/token", OAuthController, :token_exchange)
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through(:authenticated_api)

    patch("/accounts/update_credentials", MastodonAPIController, :update_credentials)
    get("/accounts/verify_credentials", MastodonAPIController, :verify_credentials)
    get("/accounts/relationships", MastodonAPIController, :relationships)
    get("/accounts/search", MastodonAPIController, :account_search)
    post("/accounts/:id/follow", MastodonAPIController, :follow)
    post("/accounts/:id/unfollow", MastodonAPIController, :unfollow)
    post("/accounts/:id/block", MastodonAPIController, :block)
    post("/accounts/:id/unblock", MastodonAPIController, :unblock)
    post("/accounts/:id/mute", MastodonAPIController, :relationship_noop)
    post("/accounts/:id/unmute", MastodonAPIController, :relationship_noop)

    get("/follow_requests", MastodonAPIController, :follow_requests)
    post("/follow_requests/:id/authorize", MastodonAPIController, :authorize_follow_request)
    post("/follow_requests/:id/reject", MastodonAPIController, :reject_follow_request)

    post("/follows", MastodonAPIController, :follow)

    get("/blocks", MastodonAPIController, :blocks)

    get("/mutes", MastodonAPIController, :empty_array)

    get("/timelines/home", MastodonAPIController, :home_timeline)

    get("/timelines/direct", MastodonAPIController, :dm_timeline)

    get("/favourites", MastodonAPIController, :favourites)

    post("/statuses", MastodonAPIController, :post_status)
    delete("/statuses/:id", MastodonAPIController, :delete_status)

    post("/statuses/:id/reblog", MastodonAPIController, :reblog_status)
    post("/statuses/:id/unreblog", MastodonAPIController, :unreblog_status)
    post("/statuses/:id/favourite", MastodonAPIController, :fav_status)
    post("/statuses/:id/unfavourite", MastodonAPIController, :unfav_status)

    post("/notifications/clear", MastodonAPIController, :clear_notifications)
    post("/notifications/dismiss", MastodonAPIController, :dismiss_notification)
    get("/notifications", MastodonAPIController, :notifications)
    get("/notifications/:id", MastodonAPIController, :get_notification)

    post("/media", MastodonAPIController, :upload)
    put("/media/:id", MastodonAPIController, :update_media)

    get("/lists", MastodonAPIController, :get_lists)
    get("/lists/:id", MastodonAPIController, :get_list)
    delete("/lists/:id", MastodonAPIController, :delete_list)
    post("/lists", MastodonAPIController, :create_list)
    put("/lists/:id", MastodonAPIController, :rename_list)
    get("/lists/:id/accounts", MastodonAPIController, :list_accounts)
    post("/lists/:id/accounts", MastodonAPIController, :add_to_list)
    delete("/lists/:id/accounts", MastodonAPIController, :remove_from_list)

    get("/domain_blocks", MastodonAPIController, :domain_blocks)
    post("/domain_blocks", MastodonAPIController, :block_domain)
    delete("/domain_blocks", MastodonAPIController, :unblock_domain)

    get("/suggestions", MastodonAPIController, :suggestions)
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
    get("/custom_emojis", MastodonAPIController, :custom_emojis)

    get("/timelines/public", MastodonAPIController, :public_timeline)
    get("/timelines/tag/:tag", MastodonAPIController, :hashtag_timeline)
    get("/timelines/list/:list_id", MastodonAPIController, :list_timeline)

    get("/statuses/:id", MastodonAPIController, :get_status)
    get("/statuses/:id/context", MastodonAPIController, :get_context)
    get("/statuses/:id/card", MastodonAPIController, :empty_object)
    get("/statuses/:id/favourited_by", MastodonAPIController, :favourited_by)
    get("/statuses/:id/reblogged_by", MastodonAPIController, :reblogged_by)

    get("/accounts/:id/statuses", MastodonAPIController, :user_statuses)
    get("/accounts/:id/followers", MastodonAPIController, :followers)
    get("/accounts/:id/following", MastodonAPIController, :following)
    get("/accounts/:id", MastodonAPIController, :user)

    get("/trends", MastodonAPIController, :empty_array)

    get("/search", MastodonAPIController, :search)
  end

  scope "/api/v2", Pleroma.Web.MastodonAPI do
    pipe_through(:api)
    get("/search", MastodonAPIController, :search2)
  end

  scope "/api", Pleroma.Web do
    pipe_through(:config)

    get("/help/test", TwitterAPI.UtilController, :help_test)
    post("/help/test", TwitterAPI.UtilController, :help_test)
    get("/statusnet/config", TwitterAPI.UtilController, :config)
    get("/statusnet/version", TwitterAPI.UtilController, :version)
  end

  scope "/api", Pleroma.Web do
    pipe_through(:api)

    get("/statuses/user_timeline", TwitterAPI.Controller, :user_timeline)
    get("/qvitter/statuses/user_timeline", TwitterAPI.Controller, :user_timeline)
    get("/users/show", TwitterAPI.Controller, :show_user)

    get("/statuses/followers", TwitterAPI.Controller, :followers)
    get("/statuses/friends", TwitterAPI.Controller, :friends)
    get("/statuses/show/:id", TwitterAPI.Controller, :fetch_status)
    get("/statusnet/conversation/:id", TwitterAPI.Controller, :fetch_conversation)

    if @registrations_open do
      post("/account/register", TwitterAPI.Controller, :register)
    end

    get("/search", TwitterAPI.Controller, :search)
    get("/statusnet/tags/timeline/:tag", TwitterAPI.Controller, :public_and_external_timeline)
  end

  scope "/api", Pleroma.Web do
    if @public do
      pipe_through(:api)
    else
      pipe_through(:authenticated_api)
    end

    get("/statuses/public_timeline", TwitterAPI.Controller, :public_timeline)

    get(
      "/statuses/public_and_external_timeline",
      TwitterAPI.Controller,
      :public_and_external_timeline
    )

    get("/statuses/networkpublic_timeline", TwitterAPI.Controller, :public_and_external_timeline)
  end

  scope "/api", Pleroma.Web do
    pipe_through(:authenticated_api)

    get("/account/verify_credentials", TwitterAPI.Controller, :verify_credentials)
    post("/account/verify_credentials", TwitterAPI.Controller, :verify_credentials)

    post("/account/update_profile", TwitterAPI.Controller, :update_profile)
    post("/account/update_profile_banner", TwitterAPI.Controller, :update_banner)
    post("/qvitter/update_background_image", TwitterAPI.Controller, :update_background)

    post(
      "/account/most_recent_notification",
      TwitterAPI.Controller,
      :update_most_recent_notification
    )

    get("/statuses/home_timeline", TwitterAPI.Controller, :friends_timeline)
    get("/statuses/friends_timeline", TwitterAPI.Controller, :friends_timeline)
    get("/statuses/mentions", TwitterAPI.Controller, :mentions_timeline)
    get("/statuses/mentions_timeline", TwitterAPI.Controller, :mentions_timeline)
    get("/qvitter/statuses/notifications", TwitterAPI.Controller, :notifications)

    post("/statuses/update", TwitterAPI.Controller, :status_update)
    post("/statuses/retweet/:id", TwitterAPI.Controller, :retweet)
    post("/statuses/unretweet/:id", TwitterAPI.Controller, :unretweet)
    post("/statuses/destroy/:id", TwitterAPI.Controller, :delete_post)

    get("/pleroma/friend_requests", TwitterAPI.Controller, :friend_requests)
    post("/pleroma/friendships/approve", TwitterAPI.Controller, :approve_friend_request)
    post("/pleroma/friendships/deny", TwitterAPI.Controller, :deny_friend_request)

    post("/friendships/create", TwitterAPI.Controller, :follow)
    post("/friendships/destroy", TwitterAPI.Controller, :unfollow)
    post("/blocks/create", TwitterAPI.Controller, :block)
    post("/blocks/destroy", TwitterAPI.Controller, :unblock)

    post("/statusnet/media/upload", TwitterAPI.Controller, :upload)
    post("/media/upload", TwitterAPI.Controller, :upload_json)

    post("/favorites/create/:id", TwitterAPI.Controller, :favorite)
    post("/favorites/create", TwitterAPI.Controller, :favorite)
    post("/favorites/destroy/:id", TwitterAPI.Controller, :unfavorite)

    post("/qvitter/update_avatar", TwitterAPI.Controller, :update_avatar)

    get("/friends/ids", TwitterAPI.Controller, :friends_ids)
    get("/friendships/no_retweets/ids", TwitterAPI.Controller, :empty_array)

    get("/mutes/users/ids", TwitterAPI.Controller, :empty_array)
    get("/qvitter/mutes", TwitterAPI.Controller, :raw_empty_array)

    get("/externalprofile/show", TwitterAPI.Controller, :external_profile)
  end

  pipeline :ostatus do
    plug(:accepts, ["xml", "atom", "html", "activity+json"])
  end

  scope "/", Pleroma.Web do
    pipe_through(:ostatus)

    get("/objects/:uuid", OStatus.OStatusController, :object)
    get("/activities/:uuid", OStatus.OStatusController, :activity)
    get("/notice/:id", OStatus.OStatusController, :notice)
    get("/users/:nickname/feed", OStatus.OStatusController, :feed)
    get("/users/:nickname", OStatus.OStatusController, :feed_redirect)

    if @federating do
      post("/users/:nickname/salmon", OStatus.OStatusController, :salmon_incoming)
      post("/push/hub/:nickname", Websub.WebsubController, :websub_subscription_request)
      get("/push/subscriptions/:id", Websub.WebsubController, :websub_subscription_confirmation)
      post("/push/subscriptions/:id", Websub.WebsubController, :websub_incoming)
    end
  end

  pipeline :activitypub do
    plug(:accepts, ["activity+json"])
    plug(Pleroma.Web.Plugs.HTTPSignaturePlug)
  end

  scope "/", Pleroma.Web.ActivityPub do
    # XXX: not really ostatus
    pipe_through(:ostatus)

    get("/users/:nickname/followers", ActivityPubController, :followers)
    get("/users/:nickname/following", ActivityPubController, :following)
    get("/users/:nickname/outbox", ActivityPubController, :outbox)
  end

  if @federating do
    scope "/", Pleroma.Web.ActivityPub do
      pipe_through(:activitypub)
      post("/users/:nickname/inbox", ActivityPubController, :inbox)
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
  end

  scope "/", Pleroma.Web.MastodonAPI do
    pipe_through(:mastodon_html)

    get("/web/login", MastodonAPIController, :login)
    post("/web/login", MastodonAPIController, :login_post)
    get("/web/*path", MastodonAPIController, :index)
    delete("/auth/sign_out", MastodonAPIController, :logout)
  end

  pipeline :remote_media do
    plug(:accepts, ["html"])
  end

  scope "/proxy/", Pleroma.Web.MediaProxy do
    pipe_through(:remote_media)
    get("/:sig/:url", MediaProxyController, :remote)
  end

  scope "/", Fallback do
    get("/*path", RedirectController, :redirector)
  end
end

defmodule Fallback.RedirectController do
  use Pleroma.Web, :controller

  def redirector(conn, _params) do
    if Mix.env() != :test do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, "priv/static/index.html")
    end
  end
end
