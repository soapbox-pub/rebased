defmodule Pleroma.Web.Router do
  use Pleroma.Web, :router

  alias Pleroma.{Repo, User, Web.Router}

  def user_fetcher(username) do
    {:ok, Repo.get_by(User, %{nickname: username})}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug Pleroma.Plugs.OAuthPlug
    plug Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1, optional: true}
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug Pleroma.Plugs.OAuthPlug
    plug Pleroma.Plugs.AuthenticationPlug, %{fetcher: &Router.user_fetcher/1}
  end

  pipeline :well_known do
    plug :accepts, ["xml", "xrd+xml"]
  end

  pipeline :config do
    plug :accepts, ["json", "xml"]
  end

  pipeline :oauth do
    plug :accepts, ["html", "json"]
  end

  pipeline :pleroma_api do
    plug :accepts, ["html", "json"]
  end

  scope "/api/pleroma", Pleroma.Web.TwitterAPI do
    pipe_through :pleroma_api
    get "/password_reset/:token", UtilController, :show_password_reset
    post "/password_reset", UtilController, :password_reset
    get "/emoji", UtilController, :emoji
  end

  scope "/oauth", Pleroma.Web.OAuth do
    get "/authorize", OAuthController, :authorize
    post "/authorize", OAuthController, :create_authorization
    post "/token", OAuthController, :token_exchange
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through :authenticated_api

    get "/accounts/verify_credentials", MastodonAPIController, :verify_credentials
    get "/accounts/relationships", MastodonAPIController, :relationships
    post "/accounts/:id/follow", MastodonAPIController, :follow
    post "/accounts/:id/unfollow", MastodonAPIController, :unfollow
    post "/accounts/:id/block", MastodonAPIController, :relationship_noop
    post "/accounts/:id/unblock", MastodonAPIController, :relationship_noop
    post "/accounts/:id/mute", MastodonAPIController, :relationship_noop
    post "/accounts/:id/unmute", MastodonAPIController, :relationship_noop

    post "/follows", MastodonAPIController, :follows

    get "/blocks", MastodonAPIController, :empty_array
    get "/domain_blocks", MastodonAPIController, :empty_array
    get "/follow_requests", MastodonAPIController, :empty_array
    get "/mutes", MastodonAPIController, :empty_array

    get "/timelines/home", MastodonAPIController, :home_timeline

    get "/favourites", MastodonAPIController, :favourites

    post "/statuses", MastodonAPIController, :post_status
    delete "/statuses/:id", MastodonAPIController, :delete_status

    post "/statuses/:id/reblog", MastodonAPIController, :reblog_status
    post "/statuses/:id/favourite", MastodonAPIController, :fav_status
    post "/statuses/:id/unfavourite", MastodonAPIController, :unfav_status

    get "/notifications", MastodonAPIController, :notifications

    post "/media", MastodonAPIController, :upload
  end

  scope "/api/v1", Pleroma.Web.MastodonAPI do
    pipe_through :api
    get "/instance", MastodonAPIController, :masto_instance
    post "/apps", MastodonAPIController, :create_app

    get "/timelines/public", MastodonAPIController, :public_timeline
    get "/timelines/tag/:tag", MastodonAPIController, :hashtag_timeline

    get "/statuses/:id", MastodonAPIController, :get_status
    get "/statuses/:id/context", MastodonAPIController, :get_context
    get "/statuses/:id/favourited_by", MastodonAPIController, :favourited_by
    get "/statuses/:id/reblogged_by", MastodonAPIController, :reblogged_by

    get "/accounts/:id/statuses", MastodonAPIController, :user_statuses
    get "/accounts/:id/followers", MastodonAPIController, :followers
    get "/accounts/:id/following", MastodonAPIController, :following
    get "/accounts/:id", MastodonAPIController, :user

    get "/search", MastodonAPIController, :search
  end

  scope "/api", Pleroma.Web do
    pipe_through :config

    get "/help/test", TwitterAPI.UtilController, :help_test
    post "/help/test", TwitterAPI.UtilController, :help_test
    get "/statusnet/config", TwitterAPI.UtilController, :config
    get "/statusnet/version", TwitterAPI.UtilController, :version
  end

  @instance Application.get_env(:pleroma, :instance)
  @registrations_open Keyword.get(@instance, :registrations_open)

  scope "/api", Pleroma.Web do
    pipe_through :api

    get "/statuses/public_timeline", TwitterAPI.Controller, :public_timeline
    get "/statuses/public_and_external_timeline", TwitterAPI.Controller, :public_and_external_timeline
    get "/statuses/networkpublic_timeline", TwitterAPI.Controller, :public_and_external_timeline
    get "/statuses/user_timeline", TwitterAPI.Controller, :user_timeline
    get "/qvitter/statuses/user_timeline", TwitterAPI.Controller, :user_timeline

    get "/statuses/show/:id", TwitterAPI.Controller, :fetch_status
    get "/statusnet/conversation/:id", TwitterAPI.Controller, :fetch_conversation

    if @registrations_open do
      post "/account/register", TwitterAPI.Controller, :register
    end

    get "/search", TwitterAPI.Controller, :search
    get "/statusnet/tags/timeline/:tag", TwitterAPI.Controller, :public_and_external_timeline
    get "/externalprofile/show", TwitterAPI.Controller, :external_profile
  end

  scope "/api", Pleroma.Web do
    pipe_through :authenticated_api

    get "/account/verify_credentials", TwitterAPI.Controller, :verify_credentials
    post "/account/verify_credentials", TwitterAPI.Controller, :verify_credentials

    post "/account/update_profile", TwitterAPI.Controller, :update_profile
    post "/account/update_profile_banner", TwitterAPI.Controller, :update_banner
    post "/qvitter/update_background_image", TwitterAPI.Controller, :update_background

    post "/account/most_recent_notification", TwitterAPI.Controller, :update_most_recent_notification

    get "/statuses/home_timeline", TwitterAPI.Controller, :friends_timeline
    get "/statuses/friends_timeline", TwitterAPI.Controller, :friends_timeline
    get "/statuses/mentions", TwitterAPI.Controller, :mentions_timeline
    get "/statuses/mentions_timeline", TwitterAPI.Controller, :mentions_timeline

    post "/statuses/update", TwitterAPI.Controller, :status_update
    post "/statuses/retweet/:id", TwitterAPI.Controller, :retweet
    post "/statuses/destroy/:id", TwitterAPI.Controller, :delete_post

    post "/friendships/create", TwitterAPI.Controller, :follow
    post "/friendships/destroy", TwitterAPI.Controller, :unfollow

    post "/statusnet/media/upload", TwitterAPI.Controller, :upload
    post "/media/upload", TwitterAPI.Controller, :upload_json

    post "/favorites/create/:id", TwitterAPI.Controller, :favorite
    post "/favorites/create", TwitterAPI.Controller, :favorite
    post "/favorites/destroy/:id", TwitterAPI.Controller, :unfavorite

    post "/qvitter/update_avatar", TwitterAPI.Controller, :update_avatar

    get "/statuses/followers", TwitterAPI.Controller, :followers
    get "/statuses/friends", TwitterAPI.Controller, :friends
  end

  pipeline :ostatus do
    plug :accepts, ["xml", "atom", "html"]
  end

  scope "/", Pleroma.Web do
    pipe_through :ostatus

    get "/objects/:uuid", OStatus.OStatusController, :object
    get "/activities/:uuid", OStatus.OStatusController, :activity

    get "/users/:nickname/feed", OStatus.OStatusController, :feed
    get "/users/:nickname", OStatus.OStatusController, :feed_redirect
    post "/users/:nickname/salmon", OStatus.OStatusController, :salmon_incoming
    post "/push/hub/:nickname", Websub.WebsubController, :websub_subscription_request
    get "/push/subscriptions/:id", Websub.WebsubController, :websub_subscription_confirmation
    post "/push/subscriptions/:id", Websub.WebsubController, :websub_incoming
  end

  scope "/.well-known", Pleroma.Web do
    pipe_through :well_known

    get "/host-meta", WebFinger.WebFingerController, :host_meta
    get "/webfinger", WebFinger.WebFingerController, :webfinger
  end

  scope "/", Fallback do
    get "/*path", RedirectController, :redirector
  end
end

defmodule Fallback.RedirectController do
  use Pleroma.Web, :controller
  def redirector(conn, _params) do
    if Mix.env != :test do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, "priv/static/index.html")
    end
  end
end
