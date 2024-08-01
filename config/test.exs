import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pleroma, Pleroma.Web.Endpoint,
  http: [port: 4001],
  url: [port: 4001],
  server: true

# Disable captha for tests
config :pleroma, Pleroma.Captcha,
  # It should not be enabled for automatic tests
  enabled: false,
  # A fake captcha service for tests
  method: Pleroma.Captcha.Mock

# Print only warnings and errors during test
config :logger, :console,
  level: :warning,
  format: "\n[$level] $message\n"

config :pleroma, :auth, oauth_consumer_strategies: []

config :pleroma, Pleroma.Upload,
  filters: [],
  link_name: false,
  default_description: :filename

config :pleroma, Pleroma.Uploaders.Local, uploads: "test/uploads"

config :pleroma, Pleroma.Emails.Mailer, adapter: Swoosh.Adapters.Test, enabled: true

config :pleroma, :instance,
  email: "admin@example.com",
  notify_email: "noreply@example.com",
  skip_thread_containment: false,
  federating: false,
  external_user_synchronization: false,
  static_dir: "test/instance_static/"

config :pleroma, :activitypub, sign_object_fetches: false, follow_handshake_timeout: 0

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "pleroma_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: System.get_env("DB_PORT") || "5432",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  log: false

config :pleroma, :dangerzone, override_repo_pool_size: true

# Reduce hash rounds for testing
config :pleroma, :password, iterations: 1

config :tesla, adapter: Tesla.Mock

config :pleroma, :rich_media,
  enabled: false,
  ignore_hosts: [],
  ignore_tld: ["local", "localdomain", "lan"],
  max_body: 2_000_000

config :pleroma, :instance,
  multi_factor_authentication: [
    totp: [
      # digits 6 or 8
      digits: 6,
      period: 30
    ],
    backup_codes: [
      number: 2,
      length: 6
    ]
  ]

config :web_push_encryption, :vapid_details,
  subject: "mailto:administrator@example.com",
  public_key:
    "BLH1qVhJItRGCfxgTtONfsOKDc9VRAraXw-3NsmjMngWSh7NxOizN6bkuRA7iLTMPS82PjwJAr3UoK9EC1IFrz4",
  private_key: "_-XZ0iebPrRfZ_o0-IatTdszYa8VCH1yLN-JauK7HHA"

config :pleroma, Oban, testing: :manual

config :pleroma, Pleroma.ScheduledActivity,
  daily_user_limit: 2,
  total_user_limit: 3,
  enabled: false

config :pleroma, :rate_limit, %{}

config :pleroma, :http_security, report_uri: "https://endpoint.com"

config :pleroma, :http, send_user_agent: false

rum_enabled = System.get_env("RUM_ENABLED") == "true"
config :pleroma, :database, rum_enabled: rum_enabled
IO.puts("RUM enabled: #{rum_enabled}")

config :joken, default_signer: "yU8uHKq+yyAkZ11Hx//jcdacWc8yQ1bxAAGrplzB0Zwwjkp35v0RK9SO8WTPr6QZ"

config :pleroma, Pleroma.ReverseProxy.Client, Pleroma.ReverseProxy.ClientMock

config :pleroma, :modules, runtime_dir: "test/fixtures/modules"

config :pleroma, Pleroma.Gun, Pleroma.GunMock

config :pleroma, Pleroma.Emails.NewUsersDigestEmail, enabled: true

config :pleroma, Pleroma.Web.Plugs.RemoteIp, enabled: false

config :pleroma, Pleroma.Web.ApiSpec.CastAndValidate, strict: true

config :tzdata, :autoupdate, :disabled

config :pleroma, :mrf, policies: []

config :pleroma, :pipeline,
  object_validator: Pleroma.Web.ActivityPub.ObjectValidatorMock,
  mrf: Pleroma.Web.ActivityPub.MRFMock,
  activity_pub: Pleroma.Web.ActivityPub.ActivityPubMock,
  side_effects: Pleroma.Web.ActivityPub.SideEffectsMock,
  federator: Pleroma.Web.FederatorMock,
  config: Pleroma.ConfigMock

config :pleroma, :cachex, provider: Pleroma.CachexMock

config :pleroma, Pleroma.Web.WebFinger, update_nickname_on_user_fetch: false

config :pleroma, :side_effects,
  ap_streamer: Pleroma.Web.ActivityPub.ActivityPubMock,
  logger: Pleroma.LoggerMock

config :pleroma, Pleroma.Search, module: Pleroma.Search.DatabaseSearch

config :pleroma, Pleroma.Search.Meilisearch, url: "http://127.0.0.1:7700/", private_key: nil

# Reduce recompilation time
# https://dashbit.co/blog/speeding-up-re-compilation-of-elixir-projects
config :phoenix, :plug_init_mode, :runtime

config :pleroma, :config_impl, Pleroma.UnstubbedConfigMock

config :pleroma, Pleroma.PromEx, disabled: true

# Mox definitions. Only read during compile time.
config :pleroma, Pleroma.User.Backup, config_impl: Pleroma.UnstubbedConfigMock
config :pleroma, Pleroma.Uploaders.S3, ex_aws_impl: Pleroma.Uploaders.S3.ExAwsMock
config :pleroma, Pleroma.Uploaders.S3, config_impl: Pleroma.UnstubbedConfigMock
config :pleroma, Pleroma.Upload, config_impl: Pleroma.UnstubbedConfigMock
config :pleroma, Pleroma.ScheduledActivity, config_impl: Pleroma.UnstubbedConfigMock
config :pleroma, Pleroma.Web.RichMedia.Helpers, config_impl: Pleroma.StaticStubbedConfigMock
config :pleroma, Pleroma.Uploaders.IPFS, config_impl: Pleroma.UnstubbedConfigMock
config :pleroma, Pleroma.Web.Plugs.HTTPSecurityPlug, config_impl: Pleroma.StaticStubbedConfigMock
config :pleroma, Pleroma.Web.Plugs.HTTPSignaturePlug, config_impl: Pleroma.StaticStubbedConfigMock

config :pleroma, Pleroma.Signature, http_signatures_impl: Pleroma.StubbedHTTPSignaturesMock

peer_module =
  if String.to_integer(System.otp_release()) >= 25 do
    :peer
  else
    :slave
  end

config :pleroma, Pleroma.Cluster, peer_module: peer_module

config :pleroma, Pleroma.Application,
  background_migrators: false,
  internal_fetch: false,
  load_custom_modules: false,
  max_restarts: 100,
  streamer_registry: false,
  test_http_pools: true

config :pleroma, Pleroma.Web.Streaming, sync_streaming: true

config :pleroma, Pleroma.Uploaders.Uploader, timeout: 1_000

config :pleroma, Pleroma.Emoji.Loader, test_emoji: true

config :pleroma, Pleroma.Web.RichMedia.Backfill,
  stream_out: Pleroma.Web.ActivityPub.ActivityPubMock

config :pleroma, Pleroma.Web.Plugs.HTTPSecurityPlug, enable: false

config :pleroma, Pleroma.User.Backup, tempdir: "test/tmp"

if File.exists?("./config/test.secret.exs") do
  import_config "test.secret.exs"
else
  IO.puts(
    "You may want to create test.secret.exs to declare custom database connection parameters."
  )
end
