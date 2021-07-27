# Soapbox default config overrides
# This file gets loaded after config.exs
# and before prod.secret.exs
use Mix.Config

# Twitter-like block behavior
config :pleroma, :activitypub, blockers_visible: false

# Set Soapbox FE as the default frontend
config :pleroma, :frontends, primary: %{"name" => "soapbox-fe", "ref" => "vendor"}

# Sane default upload filters
config :pleroma, Pleroma.Upload,
  filters: [
    Pleroma.Upload.Filter.SetMeta,
    Pleroma.Upload.Filter.Dedupe,
    Pleroma.Upload.Filter.Exiftool
  ]

# Non-RFC HTTP status codes
config :plug, :statuses, %{
  # Cloudflare
  # https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#Cloudflare
  520 => "Web Server Returned an Unknown Error",
  521 => "Web Server Is Down",
  522 => "Connection Timed Out",
  523 => "Origin Is Unreachable",
  524 => "A Timeout Occurred",
  525 => "SSL Handshake Failed",
  526 => "Invalid SSL Certificate",
  527 => "Railgun Error"
}
