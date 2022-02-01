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

# Default MRF policies
config :pleroma, :mrf,
  policies: [
    Pleroma.Web.ActivityPub.MRF.SimplePolicy,
    Pleroma.Web.ActivityPub.MRF.HellthreadPolicy,
    Pleroma.Web.ActivityPub.MRF.ObjectAgePolicy,
    Pleroma.Web.ActivityPub.MRF.TagPolicy,
    Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy
  ]

# Increase the pool size and timeout
config :pleroma, :dangerzone, override_repo_pool_size: true

config :pleroma, Pleroma.Repo,
  pool_size: 40,
  timeout: 30_000

# Allow privileged staff
config :pleroma, :instance, privileged_staff: true

# Hellthread limits
config :pleroma, :mrf_hellthread,
  delist_threshold: 15,
  reject_threshold: 100
