# Soapbox default config overrides
# This file gets loaded after config.exs
# and before prod.secret.exs
import Config

# Twitter-like block behavior
config :pleroma, :activitypub, blockers_visible: false

# Sane default upload filters
config :pleroma, Pleroma.Upload,
  filters: [
    Pleroma.Upload.Filter.AnalyzeMetadata,
    Pleroma.Upload.Filter.Dedupe,
    Pleroma.Upload.Filter.Exiftool.StripLocation
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

# Enable instance favicons
config :pleroma, :instances_favicons, enabled: true

# Hellthread limits
config :pleroma, :mrf_hellthread,
  delist_threshold: 15,
  reject_threshold: 100

# Sane default media attachment limit
config :pleroma, :instance, max_media_attachments: 20

# Use Soapbox branding
config :pleroma, :instance,
  name: "Soapbox",
  description: "Social media owned by you",
  instance_thumbnail: "/instance/thumbnail.png"

# Background migration performance
config :pleroma, :delete_context_objects, sleep_interval_ms: 3_000

# Pretend to be WhatsApp because some sites don't return link previews otherwise
config :pleroma, :rich_media, user_agent: "WhatsApp/2"
