# Configuration

## Pleroma.Upload
* `uploader`: Select which `Pleroma.Uploaders` to use
* `strip_exif`: boolean, uses ImageMagick(!) to strip exif.

## Pleroma.Uploaders.Local
* `uploads``: Which directory to store the user-uploads in, relative to pleroma’s working directory
* `uploads_url`: The URL to access a user-uploaded file, ``{{base_url}}`` is replaced to the instance URL and ``{{file}}`` to the filename. Useful when you want to proxy the media files via another host.

## ``:uri_schemes``
* `valid_schemes`: List of the scheme part that is considered valid to be an URL

## ``:instance``
* ``name``
* ``email``: Email used to reach an Administrator/Moderator of the instance
* ``description``
* ``limit``: Posts character limit
* ``upload_limit``: File size limit of uploads (except for avatar, background, banner)
* ``avatar_upload_limit``: File size limit of user’s profile avatars
* ``background_upload_limit``: File size limit of user’s profile backgrounds
* ``banner_upload_limit``: File size limit of user’s profile backgrounds
* ``registerations_open``
* ``federating``
* ``allow_relay``
* ``rewrite_policy``: Message Rewrite Policy, either one or a list.
* ``public``
* ``quarantined_instances``: List of ActivityPub instances where private(DMs, followers-only) activities will not be send.
* ``managed_config``: Whenether the config for pleroma-fe is configured in this config or in ``static/config.json``
* ``allowed_post_formats``: MIME-type list of formats allowed to be posted (transformed into HTML)
* ``finmoji_enabled``
* ``mrf_transparency``: Make the content of your Message Rewrite Facility settings public (via nodeinfo).
