# Configuration

This file describe the configuration, it is recommended to edit the relevant *.secret.exs file instead of the others founds in the ``config`` directory.
If you run Pleroma with ``MIX_ENV=prod`` the file is ``prod.secret.exs``, otherwise it is ``dev.secret.exs``.

## Pleroma.Upload
* `uploader`: Select which `Pleroma.Uploaders` to use
* `strip_exif`: boolean, uses ImageMagick(!) to strip exif.

## Pleroma.Uploaders.Local
* `uploads`: Which directory to store the user-uploads in, relative to pleroma’s working directory
* `uploads_url`: The URL to access a user-uploaded file, ``{{base_url}}`` is replaced to the instance URL and ``{{file}}`` to the filename. Useful when you want to proxy the media files via another host.

## :uri_schemes
* `valid_schemes`: List of the scheme part that is considered valid to be an URL

## :instance
* `name`: The instance’s name
* `email`: Email used to reach an Administrator/Moderator of the instance
* `description`: The instance’s description, can be seen in nodeinfo and ``/api/v1/instance``
* `limit`: Posts character limit (CW/Subject included in the counter)
* `upload_limit`: File size limit of uploads (except for avatar, background, banner)
* `avatar_upload_limit`: File size limit of user’s profile avatars
* `background_upload_limit`: File size limit of user’s profile backgrounds
* `banner_upload_limit`: File size limit of user’s profile backgrounds
* `registerations_open`: Enable registerations for anyone, invitations can be used when false.
* `federating`
* `allow_relay`: Enable Pleroma’s Relay, which makes it possible to follow a whole instance
* `rewrite_policy`: Message Rewrite Policy, either one or a list. Here are the ones available by default:
  * `Pleroma.Web.ActivityPub.MRF.NoOpPolicy`: Doesn’t modify activities (default)
  * `Pleroma.Web.ActivityPub.MRF.DropPolicy`: Drops all activities. It generally doesn’t makes sense to use in production
  * `Pleroma.Web.ActivityPub.MRF.SimplePolicy`: Restrict the visibility of activities from certains instances (See ``:mrf_simple`` section)
  * `Pleroma.Web.ActivityPub.MRF.RejectNonPublic`: Drops posts with non-public visibility settings (See ``:mrf_rejectnonpublic`` section)
* `public`: Makes the client API in authentificated mode-only except for user-profiles. Useful for disabling the Local Timeline and The Whole Known Network.
* `quarantined_instances`: List of ActivityPub instances where private(DMs, followers-only) activities will not be send.
* `managed_config`: Whenether the config for pleroma-fe is configured in this config or in ``static/config.json``
* `allowed_post_formats`: MIME-type list of formats allowed to be posted (transformed into HTML)
* `finmoji_enabled`: Whenether to enable the finmojis in the custom emojis.
* `mrf_transparency`: Make the content of your Message Rewrite Facility settings public (via nodeinfo).

## :fe
This section is used to configure Pleroma-FE, unless ``:managed_config`` in ``:instance`` is set to false.

* `theme`: Which theme to use, they are defined in ``styles.json``
* `logo`: URL of the logo, defaults to Pleroma’s logo
* `logo_mask`: Whenether to mask the logo
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

## :media_proxy
* `enabled`: Enables proxying of remote media to the instance’s proxy
* `redirect_on_failure`: Use the original URL when Media Proxy fails to get it

## :gopher
* `enabled`: Enables the gopher interface
* `ip`: IP address to bind to
* `port`: Port to bind to

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
