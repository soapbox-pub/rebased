# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :pleroma, ecto_repos: [Pleroma.Repo]

config :pleroma, Pleroma.Repo, types: Pleroma.PostgresTypes

config :pleroma, Pleroma.Upload, uploads: "uploads"

# Configures the endpoint
config :pleroma, Pleroma.Web.Endpoint,
  url: [host: "localhost"],
  protocol: "https",
  secret_key_base: "aK4Abxf29xU9TTDKre9coZPUgevcVCFQJe/5xP/7Lt4BEif6idBIbjupVbOrbKxl",
  render_errors: [view: Pleroma.Web.ErrorView, accepts: ~w(json)],
  pubsub: [name: Pleroma.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :types, %{
  "application/xml" => ["xml"],
  "application/xrd+xml" => ["xrd+xml"],
  "application/activity+json" => ["activity+json"],
  "application/ld+json" => ["activity+json"]
}

config :pleroma, :websub, Pleroma.Web.Websub
config :pleroma, :ostatus, Pleroma.Web.OStatus
config :pleroma, :httpoison, Pleroma.HTTP

version =
  with {version, 0} <- System.cmd("git", ["rev-parse", "HEAD"]) do
    "Pleroma #{Mix.Project.config()[:version]} #{String.trim(version)}"
  else
    _ -> "Pleroma #{Mix.Project.config()[:version]} dev"
  end

# Configures http settings, upstream proxy etc.
config :pleroma, :http, proxy_url: nil

config :pleroma, :instance,
  version: version,
  name: "Pleroma",
  email: "example@example.com",
  limit: 5000,
  upload_limit: 16_000_000,
  registrations_open: true,
  federating: true,
  rewrite_policy: Pleroma.Web.ActivityPub.MRF.NoOpPolicy,
  public: true,
  quarantined_instances: []

config :pleroma, :activitypub,
  accept_blocks: true,
  unfollow_blocked: true,
  outgoing_blocks: true

config :pleroma, :user, deny_follow_blocked: true

config :pleroma, :mrf_rejectnonpublic,
  allow_followersonly: false,
  allow_direct: false

config :pleroma, :mrf_simple,
  media_removal: [],
  media_nsfw: [],
  federated_timeline_removal: [],
  reject: [],
  accept: []

config :pleroma, :media_proxy,
  enabled: false,
  redirect_on_failure: true

# base_url: "https://cache.pleroma.social"

config :pleroma, :chat, enabled: true

config :ecto, json_library: Jason

config :phoenix, :format_encoders, json: Jason

config :pleroma, :gopher,
  enabled: false,
  ip: {0, 0, 0, 0},
  port: 9999

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
