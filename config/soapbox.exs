# Soapbox default config overrides
# This file gets loaded after config.exs
# and before prod.secret.exs
import Config

# Twitter-like block behavior
config :pleroma, :activitypub, blockers_visible: false

# Set Soapbox FE as the default frontend
config :pleroma, :frontends, primary: %{"name" => "soapbox-fe", "ref" => "vendor"}

# Sane default upload filters
config :pleroma, Pleroma.Upload,
  filters: [
    Pleroma.Upload.Filter.AnalyzeMetadata,
    Pleroma.Upload.Filter.Dedupe,
    Pleroma.Upload.Filter.Exiftool
  ]

# Increase the pool size and timeout
config :pleroma, :dangerzone, override_repo_pool_size: true

config :pleroma, Pleroma.Repo,
  pool_size: 40,
  timeout: 30_000
