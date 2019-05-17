use Mix.Config

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
config :logger, level: :warn

config :pleroma, Pleroma.Upload, filters: [], link_name: false

config :pleroma, Pleroma.Uploaders.Local, uploads: "test/uploads"

config :pleroma, Pleroma.Emails.Mailer, adapter: Swoosh.Adapters.Test

config :pleroma, :instance,
  email: "admin@example.com",
  notify_email: "noreply@example.com"

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "pleroma_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Reduce hash rounds for testing
config :pbkdf2_elixir, rounds: 1

config :pleroma, :websub, Pleroma.Web.WebsubMock
config :pleroma, :ostatus, Pleroma.Web.OStatusMock
config :tesla, adapter: Tesla.Mock
config :pleroma, :rich_media, enabled: false

config :web_push_encryption, :vapid_details,
  subject: "mailto:administrator@example.com",
  public_key:
    "BLH1qVhJItRGCfxgTtONfsOKDc9VRAraXw-3NsmjMngWSh7NxOizN6bkuRA7iLTMPS82PjwJAr3UoK9EC1IFrz4",
  private_key: "_-XZ0iebPrRfZ_o0-IatTdszYa8VCH1yLN-JauK7HHA"

config :web_push_encryption, :http_client, Pleroma.Web.WebPushHttpClientMock

config :pleroma_job_queue, disabled: true

config :pleroma, Pleroma.ScheduledActivity,
  daily_user_limit: 2,
  total_user_limit: 3,
  enabled: false

config :pleroma, :app_account_creation, max_requests: 5

config :pleroma, :http_security, report_uri: "https://endpoint.com"

config :pleroma, :http, send_user_agent: false

rum_enabled = System.get_env("RUM_ENABLED") == "true"
config :pleroma, :database, rum_enabled: rum_enabled
IO.puts("RUM enabled: #{rum_enabled}")

try do
  import_config "test.secret.exs"
rescue
  _ ->
    IO.puts(
      "You may want to create test.secret.exs to declare custom database connection parameters."
    )
end
