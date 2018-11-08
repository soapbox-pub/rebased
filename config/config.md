# Configuration

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
* `rewrite_policy`: Message Rewrite Policy, either one or a list.
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
* `scope_options_enabled`: Enable setting an notice visibility when posting
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

## :media_proxy
* `enabled`: Enables proxying of remote media to the instance’s proxy
* `redirect_on_failure`: Use the original URL when Media Proxy fails to get it

## :gopher
* `enabled`: Enables the gopher interface
* `ip`: IP address to bind to
* `port`: Port to bind to
