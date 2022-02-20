# Configuration Cheat Sheet

This is a cheat sheet for Pleroma configuration file, any setting possible to configure should be listed here.

For OTP installations the configuration is typically stored in `/etc/pleroma/config.exs`.

For from source installations Pleroma configuration works by first importing the base config `config/config.exs`, then overriding it by the environment config `config/$MIX_ENV.exs` and then overriding it by user config `config/$MIX_ENV.secret.exs`. In from source installations you should always make the changes to the user config and NEVER to the base config to avoid breakages and merge conflicts. So for production you change/add configuration to `config/prod.secret.exs`.

To add configuration to your config file, you can copy it from the base config. The latest version of it can be viewed [here](https://git.pleroma.social/pleroma/pleroma/blob/develop/config/config.exs). You can also use this file if you don't know how an option is supposed to be formatted.

## :shout

* `enabled` - Enables the backend Shoutbox chat feature. Defaults to `true`.
* `limit` - Shout character limit. Defaults to `5_000`

## :instance
* `name`: The instance’s name.
* `email`: Email used to reach an Administrator/Moderator of the instance.
* `notify_email`: Email used for notifications.
* `description`: The instance’s description, can be seen in nodeinfo and ``/api/v1/instance``.
* `limit`: Posts character limit (CW/Subject included in the counter).
* `description_limit`: The character limit for image descriptions.
* `remote_limit`: Hard character limit beyond which remote posts will be dropped.
* `upload_limit`: File size limit of uploads (except for avatar, background, banner).
* `avatar_upload_limit`: File size limit of user’s profile avatars.
* `background_upload_limit`: File size limit of user’s profile backgrounds.
* `banner_upload_limit`: File size limit of user’s profile banners.
* `poll_limits`: A map with poll limits for **local** polls.
    * `max_options`: Maximum number of options.
    * `max_option_chars`: Maximum number of characters per option.
    * `min_expiration`: Minimum expiration time (in seconds).
    * `max_expiration`: Maximum expiration time (in seconds).
* `registrations_open`: Enable registrations for anyone, invitations can be enabled when false.
* `invites_enabled`: Enable user invitations for admins (depends on `registrations_open: false`).
* `account_activation_required`: Require users to confirm their emails before signing in.
* `account_approval_required`: Require users to be manually approved by an admin before signing in.
* `federating`: Enable federation with other instances.
* `federation_incoming_replies_max_depth`: Max. depth of reply-to activities fetching on incoming federation, to prevent out-of-memory situations while fetching very long threads. If set to `nil`, threads of any depth will be fetched. Lower this value if you experience out-of-memory crashes.
* `federation_reachability_timeout_days`: Timeout (in days) of each external federation target being unreachable prior to pausing federating to it.
* `allow_relay`: Permits remote instances to subscribe to all public posts of your instance. This may increase the visibility of your instance.
* `public`: Makes the client API in authenticated mode-only except for user-profiles. Useful for disabling the Local Timeline and The Whole Known Network. Note that there is a dependent setting restricting or allowing unauthenticated access to specific resources, see `restrict_unauthenticated` for more details.
* `quarantined_instances`: ActivityPub instances where private (DMs, followers-only) activities will not be send.
* `allowed_post_formats`: MIME-type list of formats allowed to be posted (transformed into HTML).
* `extended_nickname_format`: Set to `true` to use extended local nicknames format (allows underscores/dashes). This will break federation with
    older software for theses nicknames.
* `max_pinned_statuses`: The maximum number of pinned statuses. `0` will disable the feature.
* `autofollowed_nicknames`: Set to nicknames of (local) users that every new user should automatically follow.
* `autofollowing_nicknames`: Set to nicknames of (local) users that automatically follows every newly registered user.
* `attachment_links`: Set to true to enable automatically adding attachment link text to statuses.
* `max_report_comment_size`: The maximum size of the report comment (Default: `1000`).
* `safe_dm_mentions`: If set to true, only mentions at the beginning of a post will be used to address people in direct messages. This is to prevent accidental mentioning of people when talking about them (e.g. "@friend hey i really don't like @enemy"). Default: `false`.
* `healthcheck`: If set to true, system data will be shown on ``/api/v1/pleroma/healthcheck``.
* `remote_post_retention_days`: The default amount of days to retain remote posts when pruning the database.
* `user_bio_length`: A user bio maximum length (default: `5000`).
* `user_name_length`: A user name maximum length (default: `100`).
* `skip_thread_containment`: Skip filter out broken threads. The default is `false`.
* `limit_to_local_content`: Limit unauthenticated users to search for local statutes and users only. Possible values: `:unauthenticated`, `:all` and `false`. The default is `:unauthenticated`.
* `max_account_fields`: The maximum number of custom fields in the user profile (default: `10`).
* `max_remote_account_fields`: The maximum number of custom fields in the remote user profile (default: `20`).
* `account_field_name_length`: An account field name maximum length (default: `512`).
* `account_field_value_length`: An account field value maximum length (default: `2048`).
* `registration_reason_length`: Maximum registration reason length (default: `500`).
* `external_user_synchronization`: Enabling following/followers counters synchronization for external users.
* `cleanup_attachments`: Remove attachments along with statuses. Does not affect duplicate files and attachments without status. Enabling this will increase load to database when deleting statuses on larger instances.
* `show_reactions`: Let favourites and emoji reactions be viewed through the API (default: `true`).
* `password_reset_token_validity`: The time after which reset tokens aren't accepted anymore, in seconds (default: one day).

## :database
* `improved_hashtag_timeline`: Setting to force toggle / force disable improved hashtags timeline. `:enabled` forces hashtags to be fetched from `hashtags` table for hashtags timeline. `:disabled` forces object-embedded hashtags to be used (slower). Keep it `:auto` for automatic behaviour (it is auto-set to `:enabled` [unless overridden] when HashtagsTableMigrator completes).

## Background migrations
* `populate_hashtags_table/sleep_interval_ms`: Sleep interval between each chunk of processed records in order to decrease the load on the system (defaults to 0 and should be keep default on most instances).
* `populate_hashtags_table/fault_rate_allowance`: Max rate of failed objects to actually processed objects in order to enable the feature (any value from 0.0 which tolerates no errors to 1.0 which will enable the feature even if hashtags transfer failed for all records).

## Welcome
* `direct_message`: - welcome message sent as a direct message.
  * `enabled`: Enables the send a direct message to a newly registered user. Defaults to `false`.
  * `sender_nickname`: The nickname of the local user that sends the welcome message.
  * `message`: A message that will be send to a newly registered users as a direct message.
* `chat_message`: - welcome message sent as a chat message.
  * `enabled`: Enables the send a chat message to a newly registered user. Defaults to `false`.
  * `sender_nickname`: The nickname of the local user that sends the welcome message.
  * `message`: A message that will be send to a newly registered users as a chat message.
* `email`: - welcome message sent as a email.
  * `enabled`: Enables the send a welcome email to a newly registered user. Defaults to `false`.
  * `sender`: The email address or tuple with `{nickname, email}` that will use as sender to the welcome email.
  * `subject`: A subject of welcome email.
  * `html`: A html that will be send to a newly registered users as a email.
  * `text`: A text that will be send to a newly registered users as a email.

    Example:

  ```elixir
  config :pleroma, :welcome,
      direct_message: [
        enabled: true,
        sender_nickname: "lain",
        message: "Hi! Welcome on board!"
        ],
      email: [
        enabled: true,
        sender: {"Pleroma App", "welcome@pleroma.app"},
        subject: "Welcome to <%= instance_name %>",
        html: "Welcome to <%= instance_name %>",
        text: "Welcome to <%= instance_name %>"
    ]
  ```

## Message rewrite facility

### :mrf
* `policies`: Message Rewrite Policy, either one or a list. Here are the ones available by default:
    * `Pleroma.Web.ActivityPub.MRF.NoOpPolicy`: Doesn’t modify activities (default).
    * `Pleroma.Web.ActivityPub.MRF.DropPolicy`: Drops all activities. It generally doesn’t makes sense to use in production.
    * `Pleroma.Web.ActivityPub.MRF.SimplePolicy`: Restrict the visibility of activities from certains instances (See [`:mrf_simple`](#mrf_simple)).
    * `Pleroma.Web.ActivityPub.MRF.TagPolicy`: Applies policies to individual users based on tags, which can be set using pleroma-fe/admin-fe/any other app that supports Pleroma Admin API. For example it allows marking posts from individual users nsfw (sensitive).
    * `Pleroma.Web.ActivityPub.MRF.SubchainPolicy`: Selectively runs other MRF policies when messages match (See [`:mrf_subchain`](#mrf_subchain)).
    * `Pleroma.Web.ActivityPub.MRF.RejectNonPublic`: Drops posts with non-public visibility settings (See [`:mrf_rejectnonpublic`](#mrf_rejectnonpublic)).
    * `Pleroma.Web.ActivityPub.MRF.EnsureRePrepended`: Rewrites posts to ensure that replies to posts with subjects do not have an identical subject and instead begin with re:.
    * `Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicy`: Rejects posts from likely spambots by rejecting posts from new users that contain links.
    * `Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy`: Crawls attachments using their MediaProxy URLs so that the MediaProxy cache is primed.
    * `Pleroma.Web.ActivityPub.MRF.MentionPolicy`: Drops posts mentioning configurable users. (See [`:mrf_mention`](#mrf_mention)).
    * `Pleroma.Web.ActivityPub.MRF.VocabularyPolicy`: Restricts activities to a configured set of vocabulary. (See [`:mrf_vocabulary`](#mrf_vocabulary)).
    * `Pleroma.Web.ActivityPub.MRF.ObjectAgePolicy`: Rejects or delists posts based on their age when received. (See [`:mrf_object_age`](#mrf_object_age)).
    * `Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy`: Sets a default expiration on all posts made by users of the local instance. Requires `Pleroma.Workers.PurgeExpiredActivity` to be enabled for processing the scheduled delections.
    * `Pleroma.Web.ActivityPub.MRF.ForceBotUnlistedPolicy`: Makes all bot posts to disappear from public timelines.
    * `Pleroma.Web.ActivityPub.MRF.FollowBotPolicy`: Automatically follows newly discovered users from the specified bot account. Local accounts, locked accounts, and users with "#nobot" in their bio are respected and excluded from being followed.
    * `Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicy`: Drops follow requests from followbots. Users can still allow bots to follow them by first following the bot.
    * `Pleroma.Web.ActivityPub.MRF.KeywordPolicy`: Rejects or removes from the federated timeline or replaces keywords. (See [`:mrf_keyword`](#mrf_keyword)).
    * `Pleroma.Web.ActivityPub.MRF.ForceMentionsInContent`: Forces every mentioned user to be reflected in the post content.
* `transparency`: Make the content of your Message Rewrite Facility settings public (via nodeinfo).
* `transparency_exclusions`: Exclude specific instance names from MRF transparency.  The use of the exclusions feature will be disclosed in nodeinfo as a boolean value.

## Federation
### MRF policies

!!! note
    Configuring MRF policies is not enough for them to take effect. You have to enable them by specifying their module in `policies` under [:mrf](#mrf) section.

#### :mrf_simple
* `media_removal`: List of instances to strip media attachments from and the reason for doing so.
* `media_nsfw`: List of instances to tag all media as NSFW (sensitive) from and the reason for doing so.
* `federated_timeline_removal`: List of instances to remove from the Federated Timeline (aka The Whole Known Network) and the reason for doing so.
* `reject`: List of instances to reject activities (except deletes) from and the reason for doing so.
* `accept`: List of instances to only accept activities (except deletes) from and the reason for doing so.
* `followers_only`: Force posts from the given instances to be visible by followers only and the reason for doing so.
* `report_removal`: List of instances to reject reports from and the reason for doing so.
* `avatar_removal`: List of instances to strip avatars from and the reason for doing so.
* `banner_removal`: List of instances to strip banners from and the reason for doing so.
* `reject_deletes`: List of instances to reject deletions from and the reason for doing so.

#### :mrf_subchain
This policy processes messages through an alternate pipeline when a given message matches certain criteria.
All criteria are configured as a map of regular expressions to lists of policy modules.

* `match_actor`: Matches a series of regular expressions against the actor field.

Example:

```elixir
config :pleroma, :mrf_subchain,
  match_actor: %{
    ~r/https:\/\/example.com/s => [Pleroma.Web.ActivityPub.MRF.DropPolicy]
  }
```

#### :mrf_rejectnonpublic
* `allow_followersonly`: whether to allow followers-only posts.
* `allow_direct`: whether to allow direct messages.

#### :mrf_hellthread
* `delist_threshold`: Number of mentioned users after which the message gets delisted (the message can still be seen, but it will not show up in public timelines and mentioned users won't get notifications about it). Set to 0 to disable.
* `reject_threshold`: Number of mentioned users after which the messaged gets rejected. Set to 0 to disable.

#### :mrf_keyword
* `reject`: A list of patterns which result in message being rejected, each pattern can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html).
* `federated_timeline_removal`: A list of patterns which result in message being removed from federated timelines (a.k.a unlisted), each pattern can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html).
* `replace`: A list of tuples containing `{pattern, replacement}`, `pattern` can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html).

#### :mrf_mention
* `actors`: A list of actors, for which to drop any posts mentioning.

#### :mrf_vocabulary
* `accept`: A list of ActivityStreams terms to accept.  If empty, all supported messages are accepted.
* `reject`: A list of ActivityStreams terms to reject.  If empty, no messages are rejected.

#### :mrf_user_allowlist

The keys in this section are the domain names that the policy should apply to.
Each key should be assigned a list of users that should be allowed through by
their ActivityPub ID.

An example:

```elixir
config :pleroma, :mrf_user_allowlist, %{
  "example.org" => ["https://example.org/users/admin"]
}
```

#### :mrf_object_age
* `threshold`: Required time offset (in seconds) compared to your server clock of an incoming post before actions are taken.
  e.g., A value of 900 results in any post with a timestamp older than 15 minutes will be acted upon.
* `actions`: A list of actions to apply to the post:
  * `:delist` removes the post from public timelines
  * `:strip_followers` removes followers from the ActivityPub recipient list, ensuring they won't be delivered to home timelines
  * `:reject` rejects the message entirely

#### :mrf_steal_emoji
* `hosts`: List of hosts to steal emojis from
* `rejected_shortcodes`: Regex-list of shortcodes to reject
* `size_limit`: File size limit (in bytes), checked before an emoji is saved to the disk

#### :mrf_activity_expiration

* `days`: Default global expiration time for all local Create activities (in days)

#### :mrf_hashtag

* `sensitive`: List of hashtags to mark activities as sensitive (default: `nsfw`)
* `federated_timeline_removal`: List of hashtags to remove activities from the federated timeline (aka TWNK)
* `reject`: List of hashtags to reject activities from

Notes:
- The hashtags in the configuration do not have a leading `#`.
- This MRF Policy is always enabled, if you want to disable it you have to set empty lists

#### :mrf_follow_bot

* `follower_nickname`: The name of the bot account to use for following newly discovered users. Using `followbot` or similar is strongly suggested.


### :activitypub
* `unfollow_blocked`: Whether blocks result in people getting unfollowed
* `outgoing_blocks`: Whether to federate blocks to other instances
* `blockers_visible`: Whether a user can see the posts of users who blocked them
* `deny_follow_blocked`: Whether to disallow following an account that has blocked the user in question
* `sign_object_fetches`: Sign object fetches with HTTP signatures
* `authorized_fetch_mode`: Require HTTP signatures for AP fetches

## Pleroma.User

* `restricted_nicknames`: List of nicknames users may not register with.
* `email_blacklist`: List of email domains users may not register with.

## Pleroma.ScheduledActivity

* `daily_user_limit`: the number of scheduled activities a user is allowed to create in a single day (Default: `25`)
* `total_user_limit`: the number of scheduled activities a user is allowed to create in total (Default: `300`)
* `enabled`: whether scheduled activities are sent to the job queue to be executed

### :frontend_configurations

This can be used to configure a keyword list that keeps the configuration data for any kind of frontend. By default, settings for `pleroma_fe` are configured. You can find the documentation for `pleroma_fe` configuration into [Pleroma-FE configuration and customization for instance administrators](/frontend/CONFIGURATION/#options).

Frontends can access these settings at `/api/v1/pleroma/frontend_configurations`

To add your own configuration for PleromaFE, use it like this:

```elixir
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
    theme: "pleroma-dark",
    # ... see /priv/static/static/config.json for the available keys.
}
```

These settings **need to be complete**, they will override the defaults.

### :static_fe

Render profiles and posts using server-generated HTML that is viewable without using JavaScript.

Available options:

* `enabled` - Enables the rendering of static HTML. Defaults to `false`.

### :assets

This section configures assets to be used with various frontends. Currently the only option
relates to mascots on the mastodon frontend

* `mascots`: KeywordList of mascots, each element __MUST__ contain both a `url` and a
  `mime_type` key.
* `default_mascot`: An element from `mascots` - This will be used as the default mascot
  on MastoFE (default: `:pleroma_fox_tan`).

### :manifest

This section describe PWA manifest instance-specific values. Currently this option relate only for MastoFE.

* `icons`: Describe the icons of the app, this a list of maps describing icons in the same way as the
  [spec](https://www.w3.org/TR/appmanifest/#imageresource-and-its-members) describes it.

  Example:

  ```elixir
  config :pleroma, :manifest,
    icons: [
      %{
        src: "/static/logo.png"
      },
      %{
        src: "/static/icon.png",
        type: "image/png"
      },
      %{
        src: "/static/icon.ico",
        sizes: "72x72 96x96 128x128 256x256"
      }
    ]
  ```

* `theme_color`: Describe the theme color of the app. (Example: `"#282c37"`, `"rebeccapurple"`).
* `background_color`: Describe the background color of the app. (Example: `"#191b22"`, `"aliceblue"`).

## :emoji

* `shortcode_globs`: Location of custom emoji files. `*` can be used as a wildcard. Example `["/emoji/custom/**/*.png"]`
* `pack_extensions`: A list of file extensions for emojis, when no emoji.txt for a pack is present. Example `[".png", ".gif"]`
* `groups`: Emojis are ordered in groups (tags). This is an array of key-value pairs where the key is the groupname and the value the location or array of locations. `*` can be used as a wildcard. Example `[Custom: ["/emoji/*.png", "/emoji/custom/*.png"]]`
* `default_manifest`: Location of the JSON-manifest. This manifest contains information about the emoji-packs you can download. Currently only one manifest can be added (no arrays).
* `shared_pack_cache_seconds_per_file`: When an emoji pack is shared, the archive is created and cached in
  memory for this amount of seconds multiplied by the number of files.

## :media_proxy

* `enabled`: Enables proxying of remote media to the instance’s proxy
* `base_url`: The base URL to access a user-uploaded file. Useful when you want to proxy the media files via another host/CDN fronts.
* `proxy_opts`: All options defined in `Pleroma.ReverseProxy` documentation, defaults to `[max_body_length: (25*1_048_576)]`.
* `whitelist`: List of hosts with scheme to bypass the mediaproxy (e.g. `https://example.com`)
* `invalidation`: options for remove media from cache after delete object:
  * `enabled`: Enables purge cache
  * `provider`: Which one of  the [purge cache strategy](#purge-cache-strategy) to use.

## :media_preview_proxy

* `enabled`: Enables proxying of remote media preview to the instance’s proxy. Requires enabled media proxy (`media_proxy/enabled`).
* `thumbnail_max_width`: Max width of preview thumbnail for images (video preview always has original dimensions).
* `thumbnail_max_height`: Max height of preview thumbnail for images (video preview always has original dimensions).
* `image_quality`: Quality of the output. Ranges from 0 (min quality) to 100 (max quality).
* `min_content_length`: Min content length to perform preview, in bytes. If greater than 0, media smaller in size will be served as is, without thumbnailing.

### Purge cache strategy

#### Pleroma.Web.MediaProxy.Invalidation.Script

This strategy allow perform external shell script to purge cache.
Urls of attachments are passed to the script as arguments.

* `script_path`: Path to the external script.
* `url_format`: Set to `:htcacheclean` if using Apache's htcacheclean utility.

Example:

```elixir
config :pleroma, Pleroma.Web.MediaProxy.Invalidation.Script,
  script_path: "./installation/nginx-cache-purge.example"
```

#### Pleroma.Web.MediaProxy.Invalidation.Http

This strategy allow perform custom http request to purge cache.

* `method`: http method. default is `purge`
* `headers`: http headers.
* `options`: request options.

Example:
```elixir
config :pleroma, Pleroma.Web.MediaProxy.Invalidation.Http,
  method: :purge,
  headers: [],
  options: []
```

## Link previews

### Pleroma.Web.Metadata (provider)
* `providers`: a list of metadata providers to enable. Providers available:
    * `Pleroma.Web.Metadata.Providers.OpenGraph`
    * `Pleroma.Web.Metadata.Providers.TwitterCard`
* `unfurl_nsfw`: If set to `true` nsfw attachments will be shown in previews.

### :rich_media (consumer)
* `enabled`: if enabled the instance will parse metadata from attached links to generate link previews.
* `ignore_hosts`: list of hosts which will be ignored by the metadata parser. For example `["accounts.google.com", "xss.website"]`, defaults to `[]`.
* `ignore_tld`: list TLDs (top-level domains) which will ignore for parse metadata. default is ["local", "localdomain", "lan"].
* `parsers`: list of Rich Media parsers.
* `failure_backoff`: Amount of milliseconds after request failure, during which the request will not be retried.

## HTTP server

### Pleroma.Web.Endpoint

!!! note
    `Phoenix` endpoint configuration, all configuration options can be viewed [here](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-dynamic-configuration), only common options are listed here.

* `http` - a list containing http protocol configuration, all configuration options can be viewed [here](https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html#module-options), only common options are listed here. For deployment using docker, you need to set this to `[ip: {0,0,0,0}, port: 4000]` to make pleroma accessible from other containers (such as your nginx server).
  - `ip` - a tuple consisting of 4 integers
  - `port`
* `url` - a list containing the configuration for generating urls, accepts
  - `host` - the host without the scheme and a post (e.g `example.com`, not `https://example.com:2020`)
  - `scheme` - e.g `http`, `https`
  - `port`
  - `path`
* `extra_cookie_attrs` - a list of `Key=Value` strings to be added as non-standard cookie attributes. Defaults to `["SameSite=Lax"]`. See the [SameSite article](https://www.owasp.org/index.php/SameSite) on OWASP for more info.

Example:
```elixir
config :pleroma, Pleroma.Web.Endpoint,
  url: [host: "example.com", port: 2020, scheme: "https"],
  http: [
    port: 8080,
    ip: {127, 0, 0, 1}
  ]
```

This will make Pleroma listen on `127.0.0.1` port `8080` and generate urls starting with `https://example.com:2020`

### :http_security
* ``enabled``: Whether the managed content security policy is enabled.
* ``sts``: Whether to additionally send a `Strict-Transport-Security` header.
* ``sts_max_age``: The maximum age for the `Strict-Transport-Security` header if sent.
* ``ct_max_age``: The maximum age for the `Expect-CT` header if sent.
* ``referrer_policy``: The referrer policy to use, either `"same-origin"` or `"no-referrer"`.
* ``report_uri``: Adds the specified url to `report-uri` and `report-to` group in CSP header.

### Pleroma.Web.Plugs.RemoteIp

!!! warning
    If your instance is not behind at least one reverse proxy, you should not enable this plug.

`Pleroma.Web.Plugs.RemoteIp` is a shim to call [`RemoteIp`](https://git.pleroma.social/pleroma/remote_ip) but with runtime configuration.

Available options:

* `enabled` - Enable/disable the plug. Defaults to `false`.
* `headers` - A list of strings naming the HTTP headers to use when deriving the true client IP address. Defaults to `["x-forwarded-for"]`.
* `proxies` - A list of upstream proxy IP subnets in CIDR notation from which we will parse the content of `headers`. Defaults to `[]`. IPv4 entries without a bitmask will be assumed to be /32 and IPv6 /128.
* `reserved` - A list of reserved IP subnets in CIDR notation which should be ignored if found in `headers`. Defaults to `["127.0.0.0/8", "::1/128", "fc00::/7", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]`.


### :rate_limit

!!! note
   If your instance is behind a reverse proxy ensure [`Pleroma.Web.Plugs.RemoteIp`](#pleroma-plugs-remoteip) is enabled (it is enabled by default).

A keyword list of rate limiters where a key is a limiter name and value is the limiter configuration. The basic configuration is a tuple where:

* The first element: `scale` (Integer). The time scale in milliseconds.
* The second element: `limit` (Integer). How many requests to limit in the time scale provided.

It is also possible to have different limits for unauthenticated and authenticated users: the keyword value must be a list of two tuples where the first one is a config for unauthenticated users and the second one is for authenticated.

For example:

```elixir
config :pleroma, :rate_limit,
  authentication: {60_000, 15},
  search: [{1000, 10}, {1000, 30}]
```

Means that:

1. In 60 seconds, 15 authentication attempts can be performed from the same IP address.
2. In 1 second, 10 search requests can be performed from the same IP adress by unauthenticated users, while authenticated users can perform 30 search requests per second.

Supported rate limiters:

* `:search` - Account/Status search.
* `:timeline` - Timeline requests (each timeline has it's own limiter).
* `:app_account_creation` - Account registration from the API.
* `:relations_actions` - Following/Unfollowing in general.
* `:relation_id_action` - Following/Unfollowing for a specific user.
* `:statuses_actions` - Status actions such as: (un)repeating, (un)favouriting, creating, deleting.
* `:status_id_action` - (un)Repeating/(un)Favouriting a particular status.
* `:authentication` - Authentication actions, i.e getting an OAuth token.
* `:password_reset` - Requesting password reset emails.
* `:account_confirmation_resend` - Requesting resending account confirmation emails.
* `:ap_routes` - Requesting statuses via ActivityPub.

### :web_cache_ttl

The expiration time for the web responses cache. Values should be in milliseconds or `nil` to disable expiration.

Available caches:

* `:activity_pub` - activity pub routes (except question activities). Defaults to `nil` (no expiration).
* `:activity_pub_question` - activity pub routes (question activities). Defaults to `30_000` (30 seconds).

## HTTP client

### :http

* `proxy_url`: an upstream proxy to fetch posts and/or media with, (default: `nil`)
* `send_user_agent`: should we include a user agent with HTTP requests? (default: `true`)
* `user_agent`: what user agent should we use? (default: `:default`), must be string or `:default`
* `adapter`: array of adapter options

### :hackney_pools

Advanced. Tweaks Hackney (http client) connections pools.

There's three pools used:

* `:federation` for the federation jobs.
  You may want this pool max_connections to be at least equal to the number of federator jobs + retry queue jobs.
* `:media` for rich media, media proxy
* `:upload` for uploaded media (if using a remote uploader and `proxy_remote: true`)

For each pool, the options are:

* `max_connections` - how much connections a pool can hold
* `timeout` - retention duration for connections


### :connections_pool

*For `gun` adapter*

Settings for HTTP connection pool.

* `:connection_acquisition_wait` - Timeout to acquire a connection from pool.The total max time is this value multiplied by the number of retries.
* `connection_acquisition_retries` - Number of attempts to acquire the connection from the pool if it is overloaded. Each attempt is timed `:connection_acquisition_wait` apart.
* `:max_connections` - Maximum number of connections in the pool.
* `:connect_timeout` - Timeout to connect to the host.
* `:reclaim_multiplier` - Multiplied by `:max_connections` this will be the maximum number of idle connections that will be reclaimed in case the pool is overloaded.

### :pools

*For `gun` adapter*

Settings for request pools. These pools are limited on top of `:connections_pool`.

There are four pools used:

* `:federation` for the federation jobs. You may want this pool's max_connections to be at least equal to the number of federator jobs + retry queue jobs.
* `:media` - for rich media, media proxy.
* `:upload` - for proxying media when a remote uploader is used and `proxy_remote: true`.
* `:default` - for other requests.

For each pool, the options are:

* `:size` - limit to how much requests can be concurrently executed.
* `:recv_timeout` - timeout while `gun` will wait for response
* `:max_waiting` - limit to how much requests can be waiting for others to finish, after this is reached, subsequent requests will be dropped.

## Captcha

### Pleroma.Captcha

* `enabled`: Whether the captcha should be shown on registration.
* `method`: The method/service to use for captcha.
* `seconds_valid`: The time in seconds for which the captcha is valid.

### Captcha providers

#### Pleroma.Captcha.Native

A built-in captcha provider. Enabled by default.

#### Pleroma.Captcha.Kocaptcha

Kocaptcha is a very simple captcha service with a single API endpoint,
the source code is here: [kocaptcha](https://github.com/koto-bank/kocaptcha). The default endpoint
`https://captcha.kotobank.ch` is hosted by the developer.

* `endpoint`: the Kocaptcha endpoint to use.

## Uploads

### Pleroma.Upload

* `uploader`: Which one of the [uploaders](#uploaders) to use.
* `filters`: List of [upload filters](#upload-filters) to use.
* `link_name`: When enabled Pleroma will add a `name` parameter to the url of the upload, for example `https://instance.tld/media/corndog.png?name=corndog.png`. This is needed to provide the correct filename in Content-Disposition headers when using filters like `Pleroma.Upload.Filter.Dedupe`
* `base_url`: The base URL to access a user-uploaded file. Useful when you want to host the media files via another domain or are using a 3rd party S3 provider.
* `proxy_remote`: If you're using a remote uploader, Pleroma will proxy media requests instead of redirecting to it.
* `proxy_opts`: Proxy options, see `Pleroma.ReverseProxy` documentation.
* `filename_display_max_length`: Set max length of a filename to display. 0 = no limit. Default: 30.
* `default_description`: Sets which default description an image has if none is set explicitly. Options: nil (default) - Don't set a default, :filename - use the filename of the file, a string (e.g. "attachment") - Use this string

!!! warning
    `strip_exif` has been replaced by `Pleroma.Upload.Filter.Mogrify`.

### Uploaders

#### Pleroma.Uploaders.Local

* `uploads`: Which directory to store the user-uploads in, relative to pleroma’s working directory.

#### Pleroma.Uploaders.S3

Don't forget to configure [Ex AWS S3](#ex-aws-s3-settings)

* `bucket`: S3 bucket name.
* `bucket_namespace`: S3 bucket namespace.
* `truncated_namespace`: If you use S3 compatible service such as Digital Ocean Spaces or CDN, set folder name or "" etc.
* `streaming_enabled`: Enable streaming uploads, when enabled the file will be sent to the server in chunks as it's being read. This may be unsupported by some providers, try disabling this if you have upload problems.

#### Ex AWS S3 settings

* `access_key_id`: Access key ID
* `secret_access_key`: Secret access key
* `host`: S3 host

Example:

```elixir
config :ex_aws, :s3,
  access_key_id: "xxxxxxxxxx",
  secret_access_key: "yyyyyyyyyy",
  host: "s3.eu-central-1.amazonaws.com"
```

### Upload filters

#### Pleroma.Upload.Filter.AnonymizeFilename

This filter replaces the filename (not the path) of an upload. For complete obfuscation, add
`Pleroma.Upload.Filter.Dedupe` before AnonymizeFilename.

* `text`: Text to replace filenames in links. If empty, `{random}.extension` will be used. You can get the original filename extension by using `{extension}`, for example `custom-file-name.{extension}`.

#### Pleroma.Upload.Filter.Dedupe

No specific configuration.

#### Pleroma.Upload.Filter.Exiftool.StripLocation

This filter only strips the GPS and location metadata with Exiftool leaving color profiles and attributes intact.

No specific configuration.

#### Pleroma.Upload.Filter.Exiftool.ReadDescription

This filter reads the ImageDescription and iptc:Caption-Abstract fields with Exiftool so clients can prefill the media description field.

No specific configuration.

#### Pleroma.Upload.Filter.Mogrify

* `args`: List of actions for the `mogrify` command like `"strip"` or `["strip", "auto-orient", {"implode", "1"}]`.

## Email

### Pleroma.Emails.Mailer
* `adapter`: one of the mail adapters listed in [Swoosh readme](https://github.com/swoosh/swoosh#adapters), or `Swoosh.Adapters.Local` for in-memory mailbox.
* `api_key` / `password` and / or other adapter-specific settings, per the above documentation.
* `enabled`: Allows enable/disable send  emails. Default: `false`.

An example for Sendgrid adapter:

```elixir
config :pleroma, Pleroma.Emails.Mailer,
  enabled: true,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: "YOUR_API_KEY"
```

An example for SMTP adapter:

```elixir
config :pleroma, Pleroma.Emails.Mailer,
  enabled: true,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: "YOUR_USERNAME@gmail.com",
  password: "YOUR_SMTP_PASSWORD",
  port: 465,
  ssl: true,
  auth: :always
```

### :email_notifications

Email notifications settings.

  - digest - emails of "what you've missed" for users who have been
    inactive for a while.
    - active: globally enable or disable digest emails
    - schedule: When to send digest email, in [crontab format](https://en.wikipedia.org/wiki/Cron).
      "0 0 * * 0" is the default, meaning "once a week at midnight on Sunday morning"
    - interval: Minimum interval between digest emails to one user
    - inactivity_threshold: Minimum user inactivity threshold

### Pleroma.Emails.UserEmail

- `:logo` - a path to a custom logo. Set it to `nil` to use the default Pleroma logo.
- `:styling` - a map with color settings for email templates.

### Pleroma.Emails.NewUsersDigestEmail

- `:enabled` - a boolean, enables new users admin digest email when `true`. Defaults to `false`.

## Background jobs

### Oban

[Oban](https://github.com/sorentwo/oban) asynchronous job processor configuration.

Configuration options described in [Oban readme](https://github.com/sorentwo/oban#usage):

* `repo` - app's Ecto repo (`Pleroma.Repo`)
* `log` - logs verbosity
* `queues` - job queues (see below)
* `crontab` - periodic jobs, see [`Oban.Cron`](#obancron)

Pleroma has the following queues:

* `activity_expiration` - Activity expiration
* `federator_outgoing` - Outgoing federation
* `federator_incoming` - Incoming federation
* `mailer` - Email sender, see [`Pleroma.Emails.Mailer`](#pleromaemailsmailer)
* `transmogrifier` - Transmogrifier
* `web_push` - Web push notifications
* `scheduled_activities` - Scheduled activities, see [`Pleroma.ScheduledActivity`](#pleromascheduledactivity)

#### Oban.Cron

Pleroma has these periodic job workers:

* `Pleroma.Workers.Cron.DigestEmailsWorker` - digest emails for users with new mentions and follows
* `Pleroma.Workers.Cron.NewUsersDigestWorker` - digest emails for admins with new registrations

```elixir
config :pleroma, Oban,
  repo: Pleroma.Repo,
  verbose: false,
  prune: {:maxlen, 1500},
  queues: [
    federator_incoming: 50,
    federator_outgoing: 50
  ],
  crontab: [
    {"0 0 * * 0", Pleroma.Workers.Cron.DigestEmailsWorker},
    {"0 0 * * *", Pleroma.Workers.Cron.NewUsersDigestWorker}
  ]
```

This config contains two queues: `federator_incoming` and `federator_outgoing`. Both have the number of max concurrent jobs set to `50`.

#### Migrating `pleroma_job_queue` settings

`config :pleroma_job_queue, :queues` is replaced by `config :pleroma, Oban, :queues` and uses the same format (keys are queues' names, values are max concurrent jobs numbers).

### :workers

Includes custom worker options not interpretable directly by `Oban`.

* `retries` — keyword lists where keys are `Oban` queues (see above) and values are numbers of max attempts for failed jobs.

Example:

```elixir
config :pleroma, :workers,
  retries: [
    federator_incoming: 5,
    federator_outgoing: 5
  ]
```

#### Migrating `Pleroma.Web.Federator.RetryQueue` settings

* `max_retries` is replaced with `config :pleroma, :workers, retries: [federator_outgoing: 5]`
* `enabled: false` corresponds to `config :pleroma, :workers, retries: [federator_outgoing: 1]`
* deprecated options: `max_jobs`, `initial_timeout`

## :web_push_encryption, :vapid_details

Web Push Notifications configuration. You can use the mix task `mix web_push.gen.keypair` to generate it.

* ``subject``: a mailto link for the administrative contact. It’s best if this email is not a personal email address, but rather a group email so that if a person leaves an organization, is unavailable for an extended period, or otherwise can’t respond, someone else on the list can.
* ``public_key``: VAPID public key
* ``private_key``: VAPID private key

## :logger
* `backends`: `:console` is used to send logs to stdout, `{ExSyslogger, :ex_syslogger}` to log to syslog, and `Quack.Logger` to log to Slack

An example to enable ONLY ExSyslogger (f/ex in ``prod.secret.exs``) with info and debug suppressed:
```elixir
config :logger,
  backends: [{ExSyslogger, :ex_syslogger}]

config :logger, :ex_syslogger,
  level: :warn
```

Another example, keeping console output and adding the pid to syslog output:
```elixir
config :logger,
  backends: [:console, {ExSyslogger, :ex_syslogger}]

config :logger, :ex_syslogger,
  level: :warn,
  option: [:pid, :ndelay]
```

See: [logger’s documentation](https://hexdocs.pm/logger/Logger.html) and [ex_syslogger’s documentation](https://hexdocs.pm/ex_syslogger/)

An example of logging info to local syslog, but warn to a Slack channel:
```elixir
config :logger,
  backends: [ {ExSyslogger, :ex_syslogger}, Quack.Logger ],
  level: :info

config :logger, :ex_syslogger,
  level: :info,
  ident: "pleroma",
  format: "$metadata[$level] $message"

config :quack,
  level: :warn,
  meta: [:all],
  webhook_url: "https://hooks.slack.com/services/YOUR-API-KEY-HERE"
```

See the [Quack Github](https://github.com/azohra/quack) for more details



## Database options

### RUM indexing for full text search

!!! warning
    It is recommended to use PostgreSQL v11 or newer. We have seen some minor issues with lower PostgreSQL versions.

* `rum_enabled`: If RUM indexes should be used. Defaults to `false`.

RUM indexes are an alternative indexing scheme that is not included in PostgreSQL by default. While they may eventually be mainlined, for now they have to be installed as a PostgreSQL extension from https://github.com/postgrespro/rum.

Their advantage over the standard GIN indexes is that they allow efficient ordering of search results by timestamp, which makes search queries a lot faster on larger servers, by one or two orders of magnitude. They take up around 3 times as much space as GIN indexes.

To enable them, both the `rum_enabled` flag has to be set and the following special migration has to be run:

`mix ecto.migrate --migrations-path priv/repo/optional_migrations/rum_indexing/`

This will probably take a long time.

## Alternative client protocols

### BBS / SSH access

To enable simple command line interface accessible over ssh, add a setting like this to your configuration file:

```exs
app_dir = File.cwd!
priv_dir = Path.join([app_dir, "priv/ssh_keys"])

config :esshd,
  enabled: true,
  priv_dir: priv_dir,
  handler: "Pleroma.BBS.Handler",
  port: 10_022,
  password_authenticator: "Pleroma.BBS.Authenticator"
```

Feel free to adjust the priv_dir and port number. Then you will have to create the key for the keys (in the example `priv/ssh_keys`) and create the host keys with `ssh-keygen -m PEM -N "" -b 2048 -t rsa -f ssh_host_rsa_key`. After restarting, you should be able to connect to your Pleroma instance with `ssh username@server -p $PORT`

### :gopher
* `enabled`: Enables the gopher interface
* `ip`: IP address to bind to
* `port`: Port to bind to
* `dstport`: Port advertised in urls (optional, defaults to `port`)


## Authentication

### :admin_token

Allows to set a token that can be used to authenticate with the admin api without using an actual user by giving it as the `admin_token` parameter or `x-admin-token` HTTP header. Example:

```elixir
config :pleroma, :admin_token, "somerandomtoken"
```

You can then do

```shell
curl "http://localhost:4000/api/v1/pleroma/admin/users/invites?admin_token=somerandomtoken"
```

or

```shell
curl -H "X-Admin-Token: somerandomtoken" "http://localhost:4000/api/v1/pleroma/admin/users/invites"
```

Warning: it's discouraged to use this feature because of the associated security risk: static / rarely changed instance-wide token is much weaker compared to email-password pair of a real admin user; consider using HTTP Basic Auth or OAuth-based authentication instead.

### :auth

Authentication / authorization settings.

* `auth_template`: authentication form template. By default it's `show.html` which corresponds to `lib/pleroma/web/templates/o_auth/o_auth/show.html.eex`.
* `oauth_consumer_template`: OAuth consumer mode authentication form template. By default it's `consumer.html` which corresponds to `lib/pleroma/web/templates/o_auth/o_auth/consumer.html.eex`.
* `oauth_consumer_strategies`: the list of enabled OAuth consumer strategies; by default it's set by `OAUTH_CONSUMER_STRATEGIES` environment variable. Each entry in this space-delimited string should be of format `<strategy>` or `<strategy>:<dependency>` (e.g. `twitter` or `keycloak:ueberauth_keycloak_strategy` in case dependency is named differently than `ueberauth_<strategy>`).

### Pleroma.Web.Auth.Authenticator

* `Pleroma.Web.Auth.PleromaAuthenticator`: default database authenticator.
* `Pleroma.Web.Auth.LDAPAuthenticator`: LDAP authentication.

### :ldap

Use LDAP for user authentication.  When a user logs in to the Pleroma
instance, the name and password will be verified by trying to authenticate
(bind) to an LDAP server.  If a user exists in the LDAP directory but there
is no account with the same name yet on the Pleroma instance then a new
Pleroma account will be created with the same name as the LDAP user name.

* `enabled`: enables LDAP authentication
* `host`: LDAP server hostname
* `port`: LDAP port, e.g. 389 or 636
* `ssl`: true to use SSL, usually implies the port 636
* `sslopts`: additional SSL options
* `tls`: true to start TLS, usually implies the port 389
* `tlsopts`: additional TLS options
* `base`: LDAP base, e.g. "dc=example,dc=com"
* `uid`: LDAP attribute name to authenticate the user, e.g. when "cn", the filter will be "cn=username,base"

Note, if your LDAP server is an Active Directory server the correct value is commonly `uid: "cn"`, but if you use an
OpenLDAP server the value may be `uid: "uid"`.

### :oauth2 (Pleroma as OAuth 2.0 provider settings)

OAuth 2.0 provider settings:

* `token_expires_in` - The lifetime in seconds of the access token.
* `issue_new_refresh_token` - Keeps old refresh token or generate new refresh token when to obtain an access token.
* `clean_expired_tokens` - Enable a background job to clean expired oauth tokens. Defaults to `false`.

OAuth 2.0 provider and related endpoints:

* `POST /api/v1/apps` creates client app basing on provided params.
* `GET/POST /oauth/authorize` renders/submits authorization form.
* `POST /oauth/token` creates/renews OAuth token.
* `POST /oauth/revoke` revokes provided OAuth token.
* `GET /api/v1/accounts/verify_credentials` (with proper `Authorization` header or `access_token` URI param) returns user info on requester (with `acct` field containing local nickname and `fqn` field containing fully-qualified nickname which could generally be used as email stub for OAuth software that demands email field in identity endpoint response, like Peertube).

### OAuth consumer mode

OAuth consumer mode allows sign in / sign up via external OAuth providers (e.g. Twitter, Facebook, Google, Microsoft, etc.).
Implementation is based on Ueberauth; see the list of [available strategies](https://github.com/ueberauth/ueberauth/wiki/List-of-Strategies).

!!! note
    Each strategy is shipped as a separate dependency; in order to get the strategies, run `OAUTH_CONSUMER_STRATEGIES="..." mix deps.get`, e.g. `OAUTH_CONSUMER_STRATEGIES="twitter facebook google microsoft" mix deps.get`.  The server should also be started with `OAUTH_CONSUMER_STRATEGIES="..." mix phx.server` in case you enable any strategies.

!!! note
    Each strategy requires separate setup (on external provider side and Pleroma side). Below are the guidelines on setting up most popular strategies.

!!! note
    Make sure that `"SameSite=Lax"` is set in `extra_cookie_attrs` when you have this feature enabled. OAuth consumer mode will not work with `"SameSite=Strict"`

* For Twitter, [register an app](https://developer.twitter.com/en/apps), configure callback URL to https://<your_host>/oauth/twitter/callback

* For Facebook, [register an app](https://developers.facebook.com/apps), configure callback URL to https://<your_host>/oauth/facebook/callback, enable Facebook Login service at https://developers.facebook.com/apps/<app_id>/fb-login/settings/

* For Google, [register an app](https://console.developers.google.com), configure callback URL to https://<your_host>/oauth/google/callback

* For Microsoft, [register an app](https://portal.azure.com), configure callback URL to https://<your_host>/oauth/microsoft/callback

Once the app is configured on external OAuth provider side, add app's credentials and strategy-specific settings (if any — e.g. see Microsoft below) to `config/prod.secret.exs`,
per strategy's documentation (e.g. [ueberauth_twitter](https://github.com/ueberauth/ueberauth_twitter)). Example config basing on environment variables:

```elixir
# Twitter
config :ueberauth, Ueberauth.Strategy.Twitter.OAuth,
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET")

# Facebook
config :ueberauth, Ueberauth.Strategy.Facebook.OAuth,
  client_id: System.get_env("FACEBOOK_APP_ID"),
  client_secret: System.get_env("FACEBOOK_APP_SECRET"),
  redirect_uri: System.get_env("FACEBOOK_REDIRECT_URI")

# Google
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  redirect_uri: System.get_env("GOOGLE_REDIRECT_URI")

# Microsoft
config :ueberauth, Ueberauth.Strategy.Microsoft.OAuth,
  client_id: System.get_env("MICROSOFT_CLIENT_ID"),
  client_secret: System.get_env("MICROSOFT_CLIENT_SECRET")

config :ueberauth, Ueberauth,
  providers: [
    microsoft: {Ueberauth.Strategy.Microsoft, [callback_params: []]}
  ]

# Keycloak
# Note: make sure to add `keycloak:ueberauth_keycloak_strategy` entry to `OAUTH_CONSUMER_STRATEGIES` environment variable
keycloak_url = "https://publicly-reachable-keycloak-instance.org:8080"

config :ueberauth, Ueberauth.Strategy.Keycloak.OAuth,
  client_id: System.get_env("KEYCLOAK_CLIENT_ID"),
  client_secret: System.get_env("KEYCLOAK_CLIENT_SECRET"),
  site: keycloak_url,
  authorize_url: "#{keycloak_url}/auth/realms/master/protocol/openid-connect/auth",
  token_url: "#{keycloak_url}/auth/realms/master/protocol/openid-connect/token",
  userinfo_url: "#{keycloak_url}/auth/realms/master/protocol/openid-connect/userinfo",
  token_method: :post

config :ueberauth, Ueberauth,
  providers: [
    keycloak: {Ueberauth.Strategy.Keycloak, [uid_field: :email]}
  ]
```

## Link parsing

### :uri_schemes
* `valid_schemes`: List of the scheme part that is considered valid to be an URL.

### Pleroma.Formatter

Configuration for Pleroma's link formatter which parses mentions, hashtags, and URLs.

* `class` - specify the class to be added to the generated link (default: `false`)
* `rel` - specify the rel attribute (default: `ugc`)
* `new_window` - adds `target="_blank"` attribute (default: `false`)
* `truncate` - Set to a number to truncate URLs longer then the number. Truncated URLs will end in `...` (default: `false`)
* `strip_prefix` - Strip the scheme prefix (default: `false`)
* `extra` - link URLs with rarely used schemes (magnet, ipfs, irc, etc.) (default: `true`)
* `validate_tld` - Set to false to disable TLD validation for URLs/emails. Can be set to :no_scheme to validate TLDs only for urls without a scheme (e.g `example.com` will be validated, but `http://example.loki` won't) (default: `:no_scheme`)

Example:

```elixir
config :pleroma, Pleroma.Formatter,
  class: false,
  rel: "ugc",
  new_window: false,
  truncate: false,
  strip_prefix: false,
  extra: true,
  validate_tld: :no_scheme
```

## Custom Runtime Modules (`:modules`)

* `runtime_dir`: A path to custom Elixir modules (such as MRF policies).

## :configurable_from_database

Boolean, enables/disables in-database configuration. Read [Transfering the config to/from the database](../administration/CLI_tasks/config.md) for more information.

## :database_config_whitelist

List of valid configuration sections which are allowed to be configured from the
database. Settings stored in the database before the whitelist is configured are
still applied, so it is suggested to only use the whitelist on instances that
have not migrated the config to the database.

Example:
```elixir
config :pleroma, :database_config_whitelist, [
  {:pleroma, :instance},
  {:pleroma, Pleroma.Web.Metadata},
  {:auto_linker}
]
```

### Multi-factor authentication -  :two_factor_authentication
* `totp` - a list containing TOTP configuration
  - `digits` - Determines the length of a one-time pass-code in characters. Defaults to 6 characters.
  - `period` - a period for which the TOTP code will be valid in seconds. Defaults to 30 seconds.
* `backup_codes` - a list containing backup codes configuration
  - `number` - number of backup codes to generate.
  - `length` - backup code length. Defaults to 16 characters.

## Restrict entities access for unauthenticated users

### :restrict_unauthenticated

Restrict access for unauthenticated users to timelines (public and federated), user profiles and statuses.

* `timelines`: public and federated timelines
  * `local`: public timeline
  * `federated`: federated timeline (includes public timeline)
* `profiles`: user profiles
  * `local`
  * `remote`
* `activities`: statuses
  * `local`
  * `remote`

Note: when `:instance, :public` is set to `false`, all `:restrict_unauthenticated` items be effectively set to `true` by default. If you'd like to allow unauthenticated access to specific API endpoints on a private instance, please explicitly set `:restrict_unauthenticated` to non-default value in `config/prod.secret.exs`.

Note: setting `restrict_unauthenticated/timelines/local` to `true` has no practical sense if `restrict_unauthenticated/timelines/federated` is set to `false` (since local public activities will still be delivered to unauthenticated users as part of federated timeline).

## Pleroma.Web.ApiSpec.CastAndValidate

* `:strict` a boolean, enables strict input validation (useful in development, not recommended in production). Defaults to `false`.

## :instances_favicons

Control favicons for instances.

* `enabled`: Allow/disallow displaying and getting instances favicons

## Pleroma.User.Backup

!!! note
    Requires enabled email

* `:purge_after_days` an integer, remove backup achives after N days.
* `:limit_days` an integer, limit user to export not more often than once per N days.
* `:dir` a string with a path to backup temporary directory or `nil` to let Pleroma choose temporary directory in the following order:
    1. the directory named by the TMPDIR environment variable
    2. the directory named by the TEMP environment variable
    3. the directory named by the TMP environment variable
    4. C:\TMP on Windows or /tmp on Unix-like operating systems
    5. as a last resort, the current working directory

## Frontend management

Frontends in Pleroma are swappable - you can specify which one to use here.

You can set a frontends for the key `primary` and `admin` and the options of `name` and `ref`. This will then make Pleroma serve the frontend from a folder constructed by concatenating the instance static path, `frontends` and the name and ref.

The key `primary` refers to the frontend that will be served by default for general requests. The key `admin` refers to the frontend that will be served at the `/pleroma/admin` path.

If you don't set anything here, the bundled frontends will be used.

Example:

```
config :pleroma, :frontends,
  primary: %{
    "name" => "pleroma",
    "ref" => "stable"
  },
  admin: %{
    "name" => "admin",
    "ref" => "develop"
  }
```

This would serve the frontend from the the folder at `$instance_static/frontends/pleroma/stable`. You have to copy the frontend into this folder yourself. You can choose the name and ref any way you like, but they will be used by mix tasks to automate installation in the future, the name referring to the project and the ref referring to a commit.

## Ephemeral activities (Pleroma.Workers.PurgeExpiredActivity)

Settings to enable and configure expiration for ephemeral activities

* `:enabled` - enables ephemeral activities creation
* `:min_lifetime` - minimum lifetime for ephemeral activities (in seconds). Default: 10 minutes.

## ConcurrentLimiter

Settings to restrict concurrently running jobs. Jobs which can be configured:

* `Pleroma.Web.RichMedia.Helpers` - generating link previews of URLs in activities
* `Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy` - warming remote media cache via MediaProxyWarmingPolicy

Each job has these settings:

* `:max_running` - max concurrently runnings jobs
* `:max_waiting` - max waiting jobs
