# pl default config overrides
# This file gets loaded after config.exs
# and before prod.secret.exs
import Config

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

# Enable instance favicons
config :pleroma, :instances_favicons, enabled: true

# Hellthread limits
config :pleroma, :mrf_hellthread,
  delist_threshold: 15,
  reject_threshold: 100

config :pleroma, :instance,
  account_approval_required: true,
  moderator_privileges: [
    :users_read,
    :users_manage_invites,
    :users_manage_activation_state,
    :users_manage_tags,
    :users_manage_credentials,
    :users_delete,
    :messages_read,
    :messages_delete,
    :instances_delete,
    :reports_manage_reports,
    :moderation_log_read,
    :announcements_manage_announcements,
    :emoji_manage_emoji,
    :statistics_read
  ]

# Background migration performance
config :pleroma, :delete_context_objects, sleep_interval_ms: 3_000

config :pleroma, :markup, allow_inline_images: false

# Pretend to be WhatsApp because some sites don't return link previews otherwise
config :pleroma, :rich_media, user_agent: "WhatsApp/2"
