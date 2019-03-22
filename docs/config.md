# Configuration

This file describe the configuration, it is recommended to edit the relevant *.secret.exs file instead of the others founds in the ``config`` directory.
If you run Pleroma with ``MIX_ENV=prod`` the file is ``prod.secret.exs``, otherwise it is ``dev.secret.exs``.

## Pleroma.Upload
* `uploader`: Select which `Pleroma.Uploaders` to use
* `filters`: List of `Pleroma.Upload.Filter` to use.
* `link_name`: When enabled Pleroma will add a `name` parameter to the url of the upload, for example `https://instance.tld/media/corndog.png?name=corndog.png`. This is needed to provide the correct filename in Content-Disposition headers when using filters like `Pleroma.Upload.Filter.Dedupe`
* `base_url`: The base URL to access a user-uploaded file. Useful when you want to proxy the media files via another host.
* `proxy_remote`: If you\'re using a remote uploader, Pleroma will proxy media requests instead of redirecting to it.
* `proxy_opts`: Proxy options, see `Pleroma.ReverseProxy` documentation.

Note: `strip_exif` has been replaced by `Pleroma.Upload.Filter.Mogrify`.

## Pleroma.Uploaders.Local
* `uploads`: Which directory to store the user-uploads in, relative to pleroma’s working directory

## Pleroma.Upload.Filter.Mogrify

* `args`: List of actions for the `mogrify` command like `"strip"` or `["strip", "auto-orient", {"impode", "1"}]`.

## Pleroma.Upload.Filter.Dedupe

No specific configuration.

## Pleroma.Upload.Filter.AnonymizeFilename

This filter replaces the filename (not the path) of an upload. For complete obfuscation, add
`Pleroma.Upload.Filter.Dedupe` before AnonymizeFilename.

* `text`: Text to replace filenames in links. If empty, `{random}.extension` will be used.

## Pleroma.Mailer
* `adapter`: one of the mail adapters listed in [Swoosh readme](https://github.com/swoosh/swoosh#adapters), or `Swoosh.Adapters.Local` for in-memory mailbox.
* `api_key` / `password` and / or other adapter-specific settings, per the above documentation.

An example for Sendgrid adapter:

```exs
config :pleroma, Pleroma.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: "YOUR_API_KEY"
```

An example for SMTP adapter:

```exs
config :pleroma, Pleroma.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: "YOUR_USERNAME@gmail.com",
  password: "YOUR_SMTP_PASSWORD",
  port: 465,
  ssl: true,
  tls: :always,
  auth: :always
```

## :uri_schemes
* `valid_schemes`: List of the scheme part that is considered valid to be an URL

## :instance
* `name`: The instance’s name
* `email`: Email used to reach an Administrator/Moderator of the instance
* `description`: The instance’s description, can be seen in nodeinfo and ``/api/v1/instance``
* `limit`: Posts character limit (CW/Subject included in the counter)
* `remote_limit`: Hard character limit beyond which remote posts will be dropped.
* `upload_limit`: File size limit of uploads (except for avatar, background, banner)
* `avatar_upload_limit`: File size limit of user’s profile avatars
* `background_upload_limit`: File size limit of user’s profile backgrounds
* `banner_upload_limit`: File size limit of user’s profile banners
* `registrations_open`: Enable registrations for anyone, invitations can be enabled when false.
* `invites_enabled`: Enable user invitations for admins (depends on `registrations_open: false`).
* `account_activation_required`: Require users to confirm their emails before signing in.
* `federating`: Enable federation with other instances
* `federation_reachability_timeout_days`: Timeout (in days) of each external federation target being unreachable prior to pausing federating to it.
* `allow_relay`: Enable Pleroma’s Relay, which makes it possible to follow a whole instance
* `rewrite_policy`: Message Rewrite Policy, either one or a list. Here are the ones available by default:
  * `Pleroma.Web.ActivityPub.MRF.NoOpPolicy`: Doesn’t modify activities (default)
  * `Pleroma.Web.ActivityPub.MRF.DropPolicy`: Drops all activities. It generally doesn’t makes sense to use in production
  * `Pleroma.Web.ActivityPub.MRF.SimplePolicy`: Restrict the visibility of activities from certains instances (See ``:mrf_simple`` section)
  * `Pleroma.Web.ActivityPub.MRF.RejectNonPublic`: Drops posts with non-public visibility settings (See ``:mrf_rejectnonpublic`` section)
  * `Pleroma.Web.ActivityPub.MRF.EnsureRePrepended`: Rewrites posts to ensure that replies to posts with subjects do not have an identical subject and instead begin with re:.
* `public`: Makes the client API in authentificated mode-only except for user-profiles. Useful for disabling the Local Timeline and The Whole Known Network.
* `quarantined_instances`: List of ActivityPub instances where private(DMs, followers-only) activities will not be send.
* `managed_config`: Whenether the config for pleroma-fe is configured in this config or in ``static/config.json``
* `allowed_post_formats`: MIME-type list of formats allowed to be posted (transformed into HTML)
* `finmoji_enabled`: Whenether to enable the finmojis in the custom emojis.
* `mrf_transparency`: Make the content of your Message Rewrite Facility settings public (via nodeinfo).
* `scope_copy`: Copy the scope (private/unlisted/public) in replies to posts by default.
* `subject_line_behavior`: Allows changing the default behaviour of subject lines in replies. Valid values:
  * "email": Copy and preprend re:, as in email.
  * "masto": Copy verbatim, as in Mastodon.
  * "noop": Don't copy the subject.
* `always_show_subject_input`: When set to false, auto-hide the subject field when it's empty.
* `extended_nickname_format`: Set to `true` to use extended local nicknames format (allows underscores/dashes). This will break federation with
    older software for theses nicknames.
* `max_pinned_statuses`: The maximum number of pinned statuses. `0` will disable the feature.
* `autofollowed_nicknames`: Set to nicknames of (local) users that every new user should automatically follow.
* `no_attachment_links`: Set to true to disable automatically adding attachment link text to statuses
* `welcome_message`: A message that will be send to a newly registered users as a direct message.
* `welcome_user_nickname`: The nickname of the local user that sends the welcome message.
* `max_report_comment_size`: The maximum size of the report comment (Default: `1000`)
* `safe_dm_mentions`: If set to true, only mentions at the beginning of a post will be used to address people in direct messages. This is to prevent accidental mentioning of people when talking about them (e.g. "@friend hey i really don't like @enemy"). (Default: `false`)

## :logger
* `backends`: `:console` is used to send logs to stdout, `{ExSyslogger, :ex_syslogger}` to log to syslog

An example to enable ONLY ExSyslogger (f/ex in ``prod.secret.exs``) with info and debug suppressed:
```
config :logger,
  backends: [{ExSyslogger, :ex_syslogger}]

config :logger, :ex_syslogger,
  level: :warn
```

Another example, keeping console output and adding the pid to syslog output:
```
config :logger,
  backends: [:console, {ExSyslogger, :ex_syslogger}]

config :logger, :ex_syslogger,
  level: :warn,
  option: [:pid, :ndelay]
```

See: [logger’s documentation](https://hexdocs.pm/logger/Logger.html) and [ex_syslogger’s documentation](https://hexdocs.pm/ex_syslogger/)


## :frontend_configurations

This can be used to configure a keyword list that keeps the configuration data for any kind of frontend. By default, settings for `pleroma_fe` and `masto_fe` are configured.

Frontends can access these settings at `/api/pleroma/frontend_configurations`

To add your own configuration for PleromaFE, use it like this:

`config :pleroma, :frontend_configurations, pleroma_fe: %{redirectRootNoLogin: "/main/all", ...}`

These settings need to be complete, they will override the defaults. See `priv/static/static/config.json` for the available keys.

## :fe
__THIS IS DEPRECATED__

If you are using this method, please change it to the `frontend_configurations` method. Please set this option to false in your config like this: `config :pleroma, :fe, false`.

This section is used to configure Pleroma-FE, unless ``:managed_config`` in ``:instance`` is set to false.

* `theme`: Which theme to use, they are defined in ``styles.json``
* `logo`: URL of the logo, defaults to Pleroma’s logo
* `logo_mask`: Whether to use only the logo's shape as a mask (true) or as a regular image (false)
* `logo_margin`: What margin to use around the logo
* `background`: URL of the background, unless viewing a user profile with a background that is set
* `redirect_root_no_login`: relative URL which indicates where to redirect when a user isn’t logged in.
* `redirect_root_login`: relative URL which indicates where to redirect when a user is logged in.
* `show_instance_panel`: Whenether to show the instance’s specific panel.
* `scope_options_enabled`: Enable setting an notice visibility and subject/CW when posting
* `formatting_options_enabled`: Enable setting a formatting different than plain-text (ie. HTML, Markdown) when posting, relates to ``:instance, allowed_post_formats``
* `collapse_message_with_subjects`: When a message has a subject(aka Content Warning), collapse it by default
* `hide_post_stats`: Hide notices statistics(repeats, favorites, …)
* `hide_user_stats`: Hide profile statistics(posts, posts per day, followers, followings, …)

## :mrf_simple
* `media_removal`: List of instances to remove medias from
* `media_nsfw`: List of instances to put medias as NSFW(sensitive) from
* `federated_timeline_removal`: List of instances to remove from Federated (aka The Whole Known Network) Timeline
* `reject`: List of instances to reject any activities from
* `accept`: List of instances to accept any activities from

## :mrf_rejectnonpublic
* `allow_followersonly`: whether to allow followers-only posts
* `allow_direct`: whether to allow direct messages

## :mrf_hellthread
* `delist_threshold`: Number of mentioned users after which the message gets delisted (the message can still be seen, but it will not show up in public timelines and mentioned users won't get notifications about it). Set to 0 to disable.
* `reject_threshold`: Number of mentioned users after which the messaged gets rejected. Set to 0 to disable.

## :mrf_keyword
* `reject`: A list of patterns which result in message being rejected, each pattern can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html)
* `federated_timeline_removal`: A list of patterns which result in message being removed from federated timelines (a.k.a unlisted), each pattern can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html)
* `replace`: A list of tuples containing `{pattern, replacement}`, `pattern` can be a string or a [regular expression](https://hexdocs.pm/elixir/Regex.html)

## :media_proxy
* `enabled`: Enables proxying of remote media to the instance’s proxy
* `base_url`: The base URL to access a user-uploaded file. Useful when you want to proxy the media files via another host/CDN fronts.
* `proxy_opts`: All options defined in `Pleroma.ReverseProxy` documentation, defaults to `[max_body_length: (25*1_048_576)]`.

## :gopher
* `enabled`: Enables the gopher interface
* `ip`: IP address to bind to
* `port`: Port to bind to
* `dstport`: Port advertised in urls (optional, defaults to `port`)

## :activitypub
* ``accept_blocks``: Whether to accept incoming block activities from other instances
* ``unfollow_blocked``: Whether blocks result in people getting unfollowed
* ``outgoing_blocks``: Whether to federate blocks to other instances
* ``deny_follow_blocked``: Whether to disallow following an account that has blocked the user in question

## :http_security
* ``enabled``: Whether the managed content security policy is enabled
* ``sts``: Whether to additionally send a `Strict-Transport-Security` header
* ``sts_max_age``: The maximum age for the `Strict-Transport-Security` header if sent
* ``ct_max_age``: The maximum age for the `Expect-CT` header if sent
* ``referrer_policy``: The referrer policy to use, either `"same-origin"` or `"no-referrer"`.

## :mrf_user_allowlist

The keys in this section are the domain names that the policy should apply to.
Each key should be assigned a list of users that should be allowed through by
their ActivityPub ID.

An example:

```exs
config :pleroma, :mrf_user_allowlist,
  "example.org": ["https://example.org/users/admin"]
```

## :web_push_encryption, :vapid_details

Web Push Notifications configuration. You can use the mix task `mix web_push.gen.keypair` to generate it.

* ``subject``: a mailto link for the administrative contact. It’s best if this email is not a personal email address, but rather a group email so that if a person leaves an organization, is unavailable for an extended period, or otherwise can’t respond, someone else on the list can.
* ``public_key``: VAPID public key
* ``private_key``: VAPID private key

## Pleroma.Captcha
* `enabled`: Whether the captcha should be shown on registration
* `method`: The method/service to use for captcha
* `seconds_valid`: The time in seconds for which the captcha is valid

### Pleroma.Captcha.Kocaptcha
Kocaptcha is a very simple captcha service with a single API endpoint,
the source code is here: https://github.com/koto-bank/kocaptcha. The default endpoint
`https://captcha.kotobank.ch` is hosted by the developer.

* `endpoint`: the kocaptcha endpoint to use

## :admin_token

Allows to set a token that can be used to authenticate with the admin api without using an actual user by giving it as the 'admin_token' parameter. Example:

```exs
config :pleroma, :admin_token, "somerandomtoken"
```

You can then do

```sh
curl "http://localhost:4000/api/pleroma/admin/invite_token?admin_token=somerandomtoken"
```

## Pleroma.Jobs

A list of job queues and their settings.

Job queue settings:

* `max_jobs`: The maximum amount of parallel jobs running at the same time.

Example:

```exs
config :pleroma, Pleroma.Jobs,
  federator_incoming: [max_jobs: 50],
  federator_outgoing: [max_jobs: 50]
```

This config contains two queues: `federator_incoming` and `federator_outgoing`. Both have the `max_jobs` set to `50`.


## Pleroma.Web.Federator.RetryQueue

* `enabled`: If set to `true`, failed federation jobs will be retried
* `max_jobs`: The maximum amount of parallel federation jobs running at the same time.
* `initial_timeout`: The initial timeout in seconds
* `max_retries`: The maximum number of times a federation job is retried

## Pleroma.Web.Metadata
* `providers`: a list of metadata providers to enable. Providers availible:
  * Pleroma.Web.Metadata.Providers.OpenGraph
  * Pleroma.Web.Metadata.Providers.TwitterCard
* `unfurl_nsfw`: If set to `true` nsfw attachments will be shown in previews

## :rich_media
* `enabled`: if enabled the instance will parse metadata from attached links to generate link previews

## :fetch_initial_posts
* `enabled`: if enabled, when a new user is federated with, fetch some of their latest posts
* `pages`: the amount of pages to fetch

## :hackney_pools

Advanced. Tweaks Hackney (http client) connections pools.

There's three pools used:

* `:federation` for the federation jobs.
  You may want this pool max_connections to be at least equal to the number of federator jobs + retry queue jobs.
* `:media` for rich media, media proxy
* `:upload` for uploaded media (if using a remote uploader and `proxy_remote: true`)

For each pool, the options are:

* `max_connections` - how much connections a pool can hold
* `timeout` - retention duration for connections

## :auto_linker

Configuration for the `auto_linker` library:

* `class: "auto-linker"` - specify the class to be added to the generated link. false to clear
* `rel: "noopener noreferrer"` - override the rel attribute. false to clear
* `new_window: true` - set to false to remove `target='_blank'` attribute
* `scheme: false` - Set to true to link urls with schema `http://google.com`
* `truncate: false` - Set to a number to truncate urls longer then the number. Truncated urls will end in `..`
* `strip_prefix: true` - Strip the scheme prefix
* `extra: false` - link urls with rarely used schemes (magnet, ipfs, irc, etc.)

Example:

```exs
config :auto_linker,
  opts: [
    scheme: true,
    extra: true,
    class: false,
    strip_prefix: false,
    new_window: false,
    rel: false
  ]
```

## :ldap

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

## Pleroma.Web.Auth.Authenticator

* `Pleroma.Web.Auth.PleromaAuthenticator`: default database authenticator
* `Pleroma.Web.Auth.LDAPAuthenticator`: LDAP authentication
