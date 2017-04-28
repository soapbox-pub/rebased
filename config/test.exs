use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pleroma, Pleroma.Web.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :pleroma, Pleroma.Upload,
  uploads: "test/uploads"

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "pleroma_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox


# Reduce hash rounds for testing
config :comeonin, :pbkdf2_rounds, 1

config :pleroma, :websub_verifier, Pleroma.Web.WebsubMock
