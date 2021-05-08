# Soapbox default config overrides
# This file gets loaded after config.exs
# and before prod.secret.exs
use Mix.Config

# Twitter-like block behavior
config :pleroma, :activitypub, blockers_visible: false

# Set Soapbox FE as the default frontend
config :pleroma, :frontends, primary: %{"name" => "soapbox-fe", "ref" => "vendor"}
