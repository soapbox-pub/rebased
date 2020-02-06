# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
### Removed
- **Breaking**: Removed 1.0+ deprecated configurations `Pleroma.Upload, :strip_exif` and `:instance, :dedupe_media`
- **Breaking**: OStatus protocol support
- **Breaking**: MDII uploader
- **Breaking**: Using third party engines for user recommendation
<details>
  <summary>API Changes</summary>
- **Breaking**: AdminAPI: migrate_from_db endpoint
</details>

### Changed
- **Breaking:** Pleroma won't start if it detects unapplied migrations
- **Breaking:** Elixir >=1.8 is now required (was >= 1.7)
- **Breaking:** `Pleroma.Plugs.RemoteIp` and `:rate_limiter` enabled by default. Please ensure your reverse proxy forwards the real IP!
- **Breaking:** attachment links (`config :pleroma, :instance, no_attachment_links` and `config :pleroma, Pleroma.Upload, link_name`) disabled by default
- **Breaking:** OAuth: defaulted `[:auth, :enforce_oauth_admin_scope_usage]` setting to `true` which demands `admin` OAuth scope to perform admin actions (in addition to `is_admin` flag on User); make sure to use bundled or newer versions of AdminFE & PleromaFE to access admin / moderator features.
- **Breaking:** Dynamic configuration has been rearchitected. The `:pleroma, :instance, dynamic_configuration` setting has been replaced with `config :pleroma, configurable_from_database`. Please backup your configuration to a file and run the migration task to ensure consistency with the new schema.
- Replaced [pleroma_job_queue](https://git.pleroma.social/pleroma/pleroma_job_queue) and `Pleroma.Web.Federator.RetryQueue` with [Oban](https://github.com/sorentwo/oban) (see [`docs/config.md`](docs/config.md) on migrating customized worker / retry settings)
- Introduced [quantum](https://github.com/quantum-elixir/quantum-core) job scheduler
- Enabled `:instance, extended_nickname_format` in the default config
- Add `rel="ugc"` to all links in statuses, to prevent SEO spam
- Extract RSS functionality from OStatus
- MRF (Simple Policy): Also use `:accept`/`:reject` on the actors rather than only their activities
- OStatus: Extract RSS functionality
- Deprecated `User.Info` embedded schema (fields moved to `User`)
- Store status data inside Flag activity
- Deprecated (reorganized as `UserRelationship` entity) User fields with user AP IDs (`blocks`, `mutes`, `muted_reblogs`, `muted_notifications`, `subscribers`).
- Rate limiter is now disabled for localhost/socket (unless remoteip plug is enabled)
- Logger: default log level changed from `warn` to `info`.
- Config mix task `migrate_to_db` truncates `config` table before migrating the config file.
<details>
  <summary>API Changes</summary>

- **Breaking** Admin API: `PATCH /api/pleroma/admin/users/:nickname/force_password_reset` is now `PATCH /api/pleroma/admin/users/force_password_reset` (accepts `nicknames` array in the request body)
- **Breaking:** Admin API: Return link alongside with token on password reset
- **Breaking:** Admin API: `PUT /api/pleroma/admin/reports/:id` is now `PATCH /api/pleroma/admin/reports`, see admin_api.md for details
- **Breaking:** `/api/pleroma/admin/users/invite_token` now uses `POST`, changed accepted params and returns full invite in json instead of only token string.
- **Breaking** replying to reports is now "report notes", enpoint changed from `POST /api/pleroma/admin/reports/:id/respond` to `POST /api/pleroma/admin/reports/:id/notes`
- Mastodon API: stopped sanitizing display names, field names and subject fields since they are supposed to be treated as plaintext
- Admin API: Return `total` when querying for reports
- Mastodon API: Return `pleroma.direct_conversation_id` when creating a direct message (`POST /api/v1/statuses`)
- Admin API: Return link alongside with token on password reset
- Admin API: Support authentication via `x-admin-token` HTTP header
- Mastodon API: Add `pleroma.direct_conversation_id` to the status endpoint (`GET /api/v1/statuses/:id`)
- Mastodon API: `pleroma.thread_muted` to the Status entity
- Mastodon API: Mark the direct conversation as read for the author when they send a new direct message
- Mastodon API, streaming: Add `pleroma.direct_conversation_id` to the `conversation` stream event payload.
- Admin API: Render whole status in grouped reports
- Mastodon API: User timelines will now respect blocks, unless you are getting the user timeline of somebody you blocked (which would be empty otherwise).
- Mastodon API: Favoriting / Repeating a post multiple times will now return the identical response every time. Before, executing that action twice would return an error ("already favorited") on the second try.
</details>

### Added
- `:chat_limit` option to limit chat characters.
- `cleanup_attachments` option to remove attachments along with statuses. Does not affect duplicate files and attachments without status. Enabling this will increase load to database when deleting statuses on larger instances.
- Refreshing poll results for remote polls
- Authentication: Added rate limit for password-authorized actions / login existence checks
- Static Frontend: Add the ability to render user profiles and notices server-side without requiring JS app.
- Mix task to re-count statuses for all users (`mix pleroma.count_statuses`)
- Mix task to list all users (`mix pleroma.user list`)
- Mix task to send a test email (`mix pleroma.email test`)
- Support for `X-Forwarded-For` and similar HTTP headers which used by reverse proxies to pass a real user IP address to the backend. Must not be enabled unless your instance is behind at least one reverse proxy (such as Nginx, Apache HTTPD or Varnish Cache).
- MRF: New module which handles incoming posts based on their age. By default, all incoming posts that are older than 2 days will be unlisted and not shown to their followers.
- User notification settings: Add `privacy_option` option.
- Support for custom Elixir modules (such as MRF policies)
- User settings: Add _This account is a_ option.
- OAuth: admin scopes support (relevant setting: `[:auth, :enforce_oauth_admin_scope_usage]`).
<details>
  <summary>API Changes</summary>

- Job queue stats to the healthcheck page
- Admin API: Add ability to fetch reports, grouped by status `GET /api/pleroma/admin/grouped_reports`
- Admin API: Add ability to require password reset
- Mastodon API: Account entities now include `follow_requests_count` (planned Mastodon 3.x addition)
- Pleroma API: `GET /api/v1/pleroma/accounts/:id/scrobbles` to get a list of recently scrobbled items
- Pleroma API: `POST /api/v1/pleroma/scrobble` to scrobble a media item
- Mastodon API: Add `upload_limit`, `avatar_upload_limit`, `background_upload_limit`, and `banner_upload_limit` to `/api/v1/instance`
- Mastodon API: Add `pleroma.unread_conversation_count` to the Account entity
- OAuth: support for hierarchical permissions / [Mastodon 2.4.3 OAuth permissions](https://docs.joinmastodon.org/api/permissions/)
- Metadata Link: Atom syndication Feed
- Mix task to re-count statuses for all users (`mix pleroma.count_statuses`)
- Mastodon API: Add `exclude_visibilities` parameter to the timeline and notification endpoints
- Admin API: `/users/:nickname/toggle_activation` endpoint is now deprecated in favor of: `/users/activate`, `/users/deactivate`, both accept `nicknames` array
- Admin API: Multiple endpoints now require `nicknames` array, instead of singe `nickname`:
  - `POST/DELETE /api/pleroma/admin/users/:nickname/permission_group/:permission_group` are deprecated in favor of: `POST/DELETE /api/pleroma/admin/users/permission_group/:permission_group`
  - `DELETE /api/pleroma/admin/users` (`nickname` query param or `nickname` sent in JSON body) is deprecated in favor of: `DELETE /api/pleroma/admin/users` (`nicknames` query array param or `nicknames` sent in JSON body)
- Admin API: Add `GET /api/pleroma/admin/relay` endpoint - lists all followed relays
- Pleroma API: `POST /api/v1/pleroma/conversations/read` to mark all conversations as read
- ActivityPub: Support `Move` activities
- Mastodon API: Add `/api/v1/markers` for managing timeline read markers
- Mastodon API: Add the `recipients` parameter to `GET /api/v1/conversations`
- Configuration: `feed` option for user atom feed.
- Pleroma API: Add Emoji reactions
- Admin API: Add `/api/pleroma/admin/instances/:instance/statuses` - lists all statuses from a given instance
- Admin API: `PATCH /api/pleroma/users/confirm_email` to confirm email for multiple users, `PATCH /api/pleroma/users/resend_confirmation_email` to resend confirmation email for multiple users
- ActivityPub: Configurable `type` field of the actors.
- Mastodon API: `/api/v1/accounts/:id` has `source/pleroma/actor_type` field.
- Mastodon API: `/api/v1/update_credentials` accepts `actor_type` field.
- Captcha: Support native provider
- Captcha: Enable by default
- Mastodon API: Add support for `account_id` param to filter notifications by the account
- Mastodon API: Add `emoji_reactions` property to Statuses
- Mastodon API: Change emoji reaction reply format
- Notifications: Added `pleroma:emoji_reaction` notification type
- Mastodon API: Change emoji reaction reply format once more
- Configuration: `feed.logo` option for tag feed.
- Tag feed: `/tags/:tag.rss` - list public statuses by hashtag.
- Mastodon API: Add `reacted` property to `emoji_reactions`
</details>

### Fixed
- Report emails now include functional links to profiles of remote user accounts
- Not being able to log in to some third-party apps when logged in to MastoFE
- MRF: `Delete` activities being exempt from MRF policies
- OTP releases: Not being able to configure OAuth expired token cleanup interval
- OTP releases: Not being able to configure HTML sanitization policy
- Favorites timeline now ordered by favorite date instead of post date
<details>
  <summary>API Changes</summary>

- Mastodon API: Fix private and direct statuses not being filtered out from the public timeline for an authenticated user (`GET /api/v1/timelines/public`)
- Mastodon API: Inability to get some local users by nickname in `/api/v1/accounts/:id_or_nickname`
- AdminAPI: If some status received reports both in the "new" format and "old" format it was considered reports on two different statuses (in the context of grouped reports)
- Admin API: Error when trying to update reports in the "old" format
- Mastodon API: Marking a conversation as read (`POST /api/v1/conversations/:id/read`) now no longer brings it to the top in the user's direct conversation list
</details>

## [1.1.6] - 2019-11-19
### Fixed
- Not being able to log into to third party apps when the browser is logged into mastofe
- Email confirmation not being required even when enabled
- Mastodon API: conversations API crashing when one status is malformed

### Bundled Pleroma-FE Changes
#### Added
- About page
- Meme arrows

#### Fixed
- Image modal not closing unless clicked outside of image
- Attachment upload spinner not being centered
- Showing follow counters being 0 when they are actually hidden

## [1.1.5] - 2019-11-09
### Fixed
- Polls having different numbers in timelines/notifications/poll api endpoints due to cache desyncronization
- Pleroma API: OAuth token endpoint not being found when ".json" suffix is appended

### Changed
- Frontend bundle updated to [044c9ad0](https://git.pleroma.social/pleroma/pleroma-fe/commit/044c9ad0562af059dd961d50961a3880fca9c642)

## [1.1.4] - 2019-11-01
### Fixed
- Added a migration that fills up empty user.info fields to prevent breakage after previous unsafe migrations.
- Failure to migrate from pre-1.0.0 versions
- Mastodon API: Notification stream not including follow notifications

## [1.1.3] - 2019-10-25
### Fixed
- Blocked users showing up in notifications collapsed as if they were muted
- `pleroma_ctl` not working on Debian's default shell

## [1.1.2] - 2019-10-18
### Fixed
- `pleroma_ctl` trying to connect to a running instance when generating the config, which of course doesn't exist.

## [1.1.1] - 2019-10-18
### Fixed
- One of the migrations between 1.0.0 and 1.1.0 wiping user info of the relay user because of unexpected behavior of postgresql's `jsonb_set`, resulting in inability to post in the default configuration. If you were affected, please run the following query in postgres console, the relay user will be recreated automatically:
```
delete from users where ap_id = 'https://your.instance.hostname/relay';
```
- Bad user search matches

## [1.1.0] - 2019-10-14
**Breaking:** The stable branch has been changed from `master` to `stable`. If you want to keep using 1.0, the `release/1.0` branch will receive security updates for 6 months after 1.1 release.

**OTP Note:** `pleroma_ctl` in 1.0 defaults to `master` and doesn't support specifying arbitrary branches, making `./pleroma_ctl update` fail. To fix this, fetch a version of `pleroma_ctl` from 1.1 using the command below and proceed with the update normally:
```
curl -Lo ./bin/pleroma_ctl 'https://git.pleroma.social/pleroma/pleroma/raw/develop/rel/files/bin/pleroma_ctl'
```
### Security
- Mastodon API: respect post privacy in `/api/v1/statuses/:id/{favourited,reblogged}_by`

### Removed
- **Breaking:** GNU Social API with Qvitter extensions support
- Emoji: Remove longfox emojis.
- Remove `Reply-To` header from report emails for admins.
- ActivityPub: The `/objects/:uuid/likes` endpoint.

### Changed
- **Breaking:** Configuration: A setting to explicitly disable the mailer was added, defaulting to true, if you are using a mailer add `config :pleroma, Pleroma.Emails.Mailer, enabled: true` to your config
- **Breaking:** Configuration: `/media/` is now removed when `base_url` is configured, append `/media/` to your `base_url` config to keep the old behaviour if desired
- **Breaking:** `/api/pleroma/notifications/read` is moved to `/api/v1/pleroma/notifications/read` and now supports `max_id` and responds with Mastodon API entities.
- Configuration: added `config/description.exs`, from which `docs/config.md` is generated
- Configuration: OpenGraph and TwitterCard providers enabled by default
- Configuration: Filter.AnonymizeFilename added ability to retain file extension with custom text
- Federation: Return 403 errors when trying to request pages from a user's follower/following collections if they have `hide_followers`/`hide_follows` set
- NodeInfo: Return `skipThreadContainment` in `metadata` for the `skip_thread_containment` option
- NodeInfo: Return `mailerEnabled` in `metadata`
- Mastodon API: Unsubscribe followers when they unfollow a user
- Mastodon API: `pleroma.thread_muted` key in the Status entity
- AdminAPI: Add "godmode" while fetching user statuses (i.e. admin can see private statuses)
- Improve digest email template
– Pagination: (optional) return `total` alongside with `items` when paginating
- The `Pleroma.FlakeId` module has been replaced with the `flake_id` library.

### Fixed
- Following from Osada
- Favorites timeline doing database-intensive queries
- Metadata rendering errors resulting in the entire page being inaccessible
- `federation_incoming_replies_max_depth` option being ignored in certain cases
- Mastodon API: Handling of search timeouts (`/api/v1/search` and `/api/v2/search`)
- Mastodon API: Misskey's endless polls being unable to render
- Mastodon API: Embedded relationships not being properly rendered in the Account entity of Status entity
- Mastodon API: Notifications endpoint crashing if one notification failed to render
- Mastodon API: `exclude_replies` is correctly handled again.
- Mastodon API: Add `account_id`, `type`, `offset`, and `limit` to search API (`/api/v1/search` and `/api/v2/search`)
- Mastodon API, streaming: Fix filtering of notifications based on blocks/mutes/thread mutes
- Mastodon API: Fix private and direct statuses not being filtered out from the public timeline for an authenticated user (`GET /api/v1/timelines/public`)
- Mastodon API: Ensure the `account` field is not empty when rendering Notification entities.
- Mastodon API: Inability to get some local users by nickname in `/api/v1/accounts/:id_or_nickname`
- Mastodon API: Blocks are now treated consistently between the Streaming API and the Timeline APIs
- Rich Media: Parser failing when no TTL can be found by image TTL setters
- Rich Media: The crawled URL is now spliced into the rich media data.
- ActivityPub S2S: sharedInbox usage has been mostly aligned with the rules in the AP specification.
- ActivityPub C2S: follower/following collection pages being inaccessible even when authentifucated if `hide_followers`/ `hide_follows` was set
- ActivityPub: Deactivated user deletion
- ActivityPub: Fix `/users/:nickname/inbox` crashing without an authenticated user
- MRF: fix ability to follow a relay when AntiFollowbotPolicy was enabled
- ActivityPub: Correct addressing of Undo.
- ActivityPub: Correct addressing of profile update activities.
- ActivityPub: Polls are now refreshed when necessary.
- Report emails now include functional links to profiles of remote user accounts
- Existing user id not being preserved on insert conflict
- Pleroma.Upload base_url was not automatically whitelisted by MediaProxy. Now your custom CDN or file hosting will be accessed directly as expected.
- Report email not being sent to admins when the reporter is a remote user
- Reverse Proxy limiting `max_body_length` was incorrectly defined and only checked `Content-Length` headers which may not be sufficient in some circumstances

### Added
- Expiring/ephemeral activites. All activities can have expires_at value set, which controls when they should be deleted automatically.
- Mastodon API: in post_status, the expires_in parameter lets you set the number of seconds until an activity expires. It must be at least one hour.
- Mastodon API: all status JSON responses contain a `pleroma.expires_at` item which states when an activity will expire. The value is only shown to the user who created the activity. To everyone else it's empty.
- Configuration: `ActivityExpiration.enabled` controls whether expired activites will get deleted at the appropriate time. Enabled by default.
- Conversations: Add Pleroma-specific conversation endpoints and status posting extensions. Run the `bump_all_conversations` task again to create the necessary data.
- MRF: Support for priming the mediaproxy cache (`Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy`)
- MRF: Support for excluding specific domains from Transparency.
- MRF: Support for filtering posts based on who they mention (`Pleroma.Web.ActivityPub.MRF.MentionPolicy`)
- Mastodon API: Support for the [`tagged` filter](https://github.com/tootsuite/mastodon/pull/9755) in [`GET /api/v1/accounts/:id/statuses`](https://docs.joinmastodon.org/api/rest/accounts/#get-api-v1-accounts-id-statuses)
- Mastodon API, streaming: Add support for passing the token in the `Sec-WebSocket-Protocol` header
- Mastodon API, extension: Ability to reset avatar, profile banner, and background
- Mastodon API: Add support for `fields_attributes` API parameter (setting custom fields)
- Mastodon API: Add support for categories for custom emojis by reusing the group feature. <https://github.com/tootsuite/mastodon/pull/11196>
- Mastodon API: Add support for muting/unmuting notifications
- Mastodon API: Add support for the `blocked_by` attribute in the relationship API (`GET /api/v1/accounts/relationships`). <https://github.com/tootsuite/mastodon/pull/10373>
- Mastodon API: Add support for the `domain_blocking` attribute in the relationship API (`GET /api/v1/accounts/relationships`).
- Mastodon API: Add `pleroma.deactivated` to the Account entity
- Mastodon API: added `/auth/password` endpoint for password reset with rate limit.
- Mastodon API: /api/v1/accounts/:id/statuses now supports nicknames or user id
- Mastodon API: Improve support for the user profile custom fields
- Mastodon API: Add support for `fields_attributes` API parameter (setting custom fields)
- Mastodon API: Added an endpoint to get multiple statuses by IDs (`GET /api/v1/statuses/?ids[]=1&ids[]=2`)
- Admin API: Return users' tags when querying reports
- Admin API: Return avatar and display name when querying users
- Admin API: Allow querying user by ID
- Admin API: Added support for `tuples`.
- Admin API: Added endpoints to run mix tasks pleroma.config migrate_to_db & pleroma.config migrate_from_db
- Added synchronization of following/followers counters for external users
- Configuration: `enabled` option for `Pleroma.Emails.Mailer`, defaulting to `false`.
- Configuration: Pleroma.Plugs.RateLimiter `bucket_name`, `params` options.
- Configuration: `user_bio_length` and `user_name_length` options.
- Addressable lists
- Twitter API: added rate limit for `/api/account/password_reset` endpoint.
- ActivityPub: Add an internal service actor for fetching ActivityPub objects.
- ActivityPub: Optional signing of ActivityPub object fetches.
- Admin API: Endpoint for fetching latest user's statuses
- Pleroma API: Add `/api/v1/pleroma/accounts/confirmation_resend?email=<email>` for resending account confirmation.
- Pleroma API: Email change endpoint.
- Admin API: Added moderation log
- Web response cache (currently, enabled for ActivityPub)
- Reverse Proxy: Do not retry failed requests to limit pressure on the peer

### Changed
- Configuration: Filter.AnonymizeFilename added ability to retain file extension with custom text
- Admin API: changed json structure for saving config settings.
- RichMedia: parsers and their order are configured in `rich_media` config.
- RichMedia: add the rich media ttl based on image expiration time.

## [1.0.7] - 2019-09-26
### Fixed
- Broken federation on Erlang 22 (previous versions of hackney http client were using an option that got deprecated)
### Changed
- ActivityPub: The first page in inboxes/outboxes is no longer embedded.

## [1.0.6] - 2019-08-14
### Fixed
- MRF: fix use of unserializable keyword lists in describe() implementations
- ActivityPub S2S: POST requests are now signed with `(request-target)` pseudo-header.

## [1.0.5] - 2019-08-13
### Fixed
- Mastodon API: follower/following counters not being nullified, when `hide_follows`/`hide_followers` is set
- Mastodon API: `muted` in the Status entity, using author's account to determine if the thread was muted
- Mastodon API: return the actual profile URL in the Account entity's `url` property when appropriate
- Templates: properly style anchor tags
- Objects being re-embedded to activities after being updated (e.g faved/reposted). Running 'mix pleroma.database prune_objects' again is advised.
- Not being able to access the Mastodon FE login page on private instances
- MRF: ensure that subdomain_match calls are case-insensitive
- Fix internal server error when using the healthcheck API.

### Added
- **Breaking:** MRF describe API, which adds support for exposing configuration information about MRF policies to NodeInfo.
  Custom modules will need to be updated by adding, at the very least, `def describe, do: {:ok, %{}}` to the MRF policy modules.
- Relays: Added a task to list relay subscriptions.
- MRF: Support for filtering posts based on ActivityStreams vocabulary (`Pleroma.Web.ActivityPub.MRF.VocabularyPolicy`)
- MRF (Simple Policy): Support for wildcard domains.
- Support for wildcard domains in user domain blocks setting.
- Configuration: `quarantined_instances` support wildcard domains.
- Mix Tasks: `mix pleroma.database fix_likes_collections`
- Configuration: `federation_incoming_replies_max_depth` option

### Removed
- Federation: Remove `likes` from objects.
- **Breaking:** ActivityPub: The `accept_blocks` configuration setting.

## [1.0.4] - 2019-08-01
### Fixed
- Invalid SemVer version generation, when the current branch does not have commits ahead of tag/checked out on a tag

## [1.0.3] - 2019-07-31
### Security
- OStatus: eliminate the possibility of a protocol downgrade attack.
- OStatus: prevent following locked accounts, bypassing the approval process.
- TwitterAPI: use CommonAPI to handle remote follows instead of OStatus.

## [1.0.2] - 2019-07-28
### Fixed
- Not being able to pin unlisted posts
- Mastodon API: represent poll IDs as strings
- MediaProxy: fix matching filenames
- MediaProxy: fix filename encoding
- Migrations: fix a sporadic migration failure
- Metadata rendering errors resulting in the entire page being inaccessible
- Federation/MediaProxy not working with instances that have wrong certificate order
- ActivityPub S2S: remote user deletions now work the same as local user deletions.

### Changed
- Configuration: OpenGraph and TwitterCard providers enabled by default
- Configuration: Filter.AnonymizeFilename added ability to retain file extension with custom text

## [1.0.1] - 2019-07-14
### Security
- OStatus: fix an object spoofing vulnerability.

## [1.0.0] - 2019-06-29
### Security
- Mastodon API: Fix display names not being sanitized
- Rich media: Do not crawl private IP ranges

### Added
- Digest email for inactive users
- Add a generic settings store for frontends / clients to use.
- Explicit addressing option for posting.
- Optional SSH access mode. (Needs `erlang-ssh` package on some distributions).
- [MongooseIM](https://github.com/esl/MongooseIM) http authentication support.
- LDAP authentication
- External OAuth provider authentication
- Support for building a release using [`mix release`](https://hexdocs.pm/mix/master/Mix.Tasks.Release.html)
- A [job queue](https://git.pleroma.social/pleroma/pleroma_job_queue) for federation, emails, web push, etc.
- [Prometheus](https://prometheus.io/) metrics
- Support for Mastodon's remote interaction
- Mix Tasks: `mix pleroma.database bump_all_conversations`
- Mix Tasks: `mix pleroma.database remove_embedded_objects`
- Mix Tasks: `mix pleroma.database update_users_following_followers_counts`
- Mix Tasks: `mix pleroma.user toggle_confirmed`
- Mix Tasks: `mix pleroma.config migrate_to_db`
- Mix Tasks: `mix pleroma.config migrate_from_db`
- Federation: Support for `Question` and `Answer` objects
- Federation: Support for reports
- Configuration: `poll_limits` option
- Configuration: `pack_extensions` option
- Configuration: `safe_dm_mentions` option
- Configuration: `link_name` option
- Configuration: `fetch_initial_posts` option
- Configuration: `notify_email` option
- Configuration: Media proxy `whitelist` option
- Configuration: `report_uri` option
- Configuration: `email_notifications` option
- Configuration: `limit_to_local_content` option
- Pleroma API: User subscriptions
- Pleroma API: Healthcheck endpoint
- Pleroma API: `/api/v1/pleroma/mascot` per-user frontend mascot configuration endpoints
- Admin API: Endpoints for listing/revoking invite tokens
- Admin API: Endpoints for making users follow/unfollow each other
- Admin API: added filters (role, tags, email, name) for users endpoint
- Admin API: Endpoints for managing reports
- Admin API: Endpoints for deleting and changing the scope of individual reported statuses
- Admin API: Endpoints to view and change config settings.
- AdminFE: initial release with basic user management accessible at /pleroma/admin/
- Mastodon API: Add chat token to `verify_credentials` response
- Mastodon API: Add background image setting to `update_credentials`
- Mastodon API: [Scheduled statuses](https://docs.joinmastodon.org/api/rest/scheduled-statuses/)
- Mastodon API: `/api/v1/notifications/destroy_multiple` (glitch-soc extension)
- Mastodon API: `/api/v1/pleroma/accounts/:id/favourites` (API extension)
- Mastodon API: [Reports](https://docs.joinmastodon.org/api/rest/reports/)
- Mastodon API: `POST /api/v1/accounts` (account creation API)
- Mastodon API: [Polls](https://docs.joinmastodon.org/api/rest/polls/)
- ActivityPub C2S: OAuth endpoints
- Metadata: RelMe provider
- OAuth: added support for refresh tokens
- Emoji packs and emoji pack manager
- Object pruning (`mix pleroma.database prune_objects`)
- OAuth: added job to clean expired access tokens
- MRF: Support for rejecting reports from specific instances (`mrf_simple`)
- MRF: Support for stripping avatars and banner images from specific instances (`mrf_simple`)
- MRF: Support for running subchains.
- Configuration: `skip_thread_containment` option
- Configuration: `rate_limit` option. See `Pleroma.Plugs.RateLimiter` documentation for details.
- MRF: Support for filtering out likely spam messages by rejecting posts from new users that contain links.
- Configuration: `ignore_hosts` option
- Configuration: `ignore_tld` option
- Configuration: default syslog tag "Pleroma" is now lowercased to "pleroma"

### Changed
- **Breaking:** bind to 127.0.0.1 instead of 0.0.0.0 by default
- **Breaking:** Configuration: move from Pleroma.Mailer to Pleroma.Emails.Mailer
- Thread containment / test for complete visibility will be skipped by default.
- Enforcement of OAuth scopes
- Add multiple use/time expiring invite token
- Restyled OAuth pages to fit with Pleroma's default theme
- Link/mention/hashtag detection is now handled by [auto_linker](https://git.pleroma.social/pleroma/auto_linker)
- NodeInfo: Return `safe_dm_mentions` feature flag
- Federation: Expand the audience of delete activities to all recipients of the deleted object
- Federation: Removed `inReplyToStatusId` from objects
- Configuration: Dedupe enabled by default
- Configuration: Default log level in `prod` environment is now set to `warn`
- Configuration: Added `extra_cookie_attrs` for setting non-standard cookie attributes. Defaults to ["SameSite=Lax"] so that remote follows work.
- Timelines: Messages involving people you have blocked will be excluded from the timeline in all cases instead of just repeats.
- Admin API: Move the user related API to `api/pleroma/admin/users`
- Admin API: `POST /api/pleroma/admin/users` will take list of users
- Pleroma API: Support for emoji tags in `/api/pleroma/emoji` resulting in a breaking API change
- Mastodon API: Support for `exclude_types`, `limit` and `min_id` in `/api/v1/notifications`
- Mastodon API: Add `languages` and `registrations` to `/api/v1/instance`
- Mastodon API: Provide plaintext versions of cw/content in the Status entity
- Mastodon API: Add `pleroma.conversation_id`, `pleroma.in_reply_to_account_acct` fields to the Status entity
- Mastodon API: Add `pleroma.tags`, `pleroma.relationship{}`, `pleroma.is_moderator`, `pleroma.is_admin`, `pleroma.confirmation_pending`, `pleroma.hide_followers`, `pleroma.hide_follows`, `pleroma.hide_favorites` fields to the User entity
- Mastodon API: Add `pleroma.show_role`, `pleroma.no_rich_text` fields to the Source subentity
- Mastodon API: Add support for updating `no_rich_text`, `hide_followers`, `hide_follows`, `hide_favorites`, `show_role` in `PATCH /api/v1/update_credentials`
- Mastodon API: Add `pleroma.is_seen` to the Notification entity
- Mastodon API: Add `pleroma.local` to the Status entity
- Mastodon API: Add `preview` parameter to `POST /api/v1/statuses`
- Mastodon API: Add `with_muted` parameter to timeline endpoints
- Mastodon API: Actual reblog hiding instead of a dummy
- Mastodon API: Remove attachment limit in the Status entity
- Mastodon API: Added support max_id & since_id for bookmark timeline endpoints.
- Deps: Updated Cowboy to 2.6
- Deps: Updated Ecto to 3.0.7
- Don't ship finmoji by default, they can be installed as an emoji pack
- Hide deactivated users and their statuses
- Posts which are marked sensitive or tagged nsfw no longer have link previews.
- HTTP connection timeout is now set to 10 seconds.
- Respond with a 404 Not implemented JSON error message when requested API is not implemented
- Rich Media: crawl only https URLs.

### Fixed
- Follow requests don't get 'stuck' anymore.
- Added an FTS index on objects. Running `vacuum analyze` and setting a larger `work_mem` is recommended.
- Followers counter not being updated when a follower is blocked
- Deactivated users being able to request an access token
- Limit on request body in rich media/relme parsers being ignored resulting in a possible memory leak
- Proper Twitter Card generation instead of a dummy
- Deletions failing for users with a large number of posts
- NodeInfo: Include admins in `staffAccounts`
- ActivityPub: Crashing when requesting empty local user's outbox
- Federation: Handling of objects without `summary` property
- Federation: Add a language tag to activities as required by ActivityStreams 2.0
- Federation: Do not federate avatar/banner if set to default allowing other servers/clients to use their defaults
- Federation: Cope with missing or explicitly nulled address lists
- Federation: Explicitly ensure activities addressed to `as:Public` become addressed to the followers collection
- Federation: Better cope with actors which do not declare a followers collection and use `as:Public` with these semantics
- Federation: Follow requests from remote users who have been blocked will be automatically rejected if appropriate
- MediaProxy: Parse name from content disposition headers even for non-whitelisted types
- MediaProxy: S3 link encoding
- Rich Media: Reject any data which cannot be explicitly encoded into JSON
- Pleroma API: Importing follows from Mastodon 2.8+
- Twitter API: Exposing default scope, `no_rich_text` of the user to anyone
- Twitter API: Returning the `role` object in user entity despite `show_role = false`
- Mastodon API: `/api/v1/favourites` serving only public activities
- Mastodon API: Reblogs having `in_reply_to_id` - `null` even when they are replies
- Mastodon API: Streaming API broadcasting wrong activity id
- Mastodon API: 500 errors when requesting a card for a private conversation
- Mastodon API: Handling of `reblogs` in `/api/v1/accounts/:id/follow`
- Mastodon API: Correct `reblogged`, `favourited`, and `bookmarked` values in the reblog status JSON
- Mastodon API: Exposing default scope of the user to anyone
- Mastodon API: Make `irreversible` field default to `false` [`POST /api/v1/filters`]
- Mastodon API: Replace missing non-nullable Card attributes with empty strings
- User-Agent is now sent correctly for all HTTP requests.
- MRF: Simple policy now properly delists imported or relayed statuses

## Removed
- Configuration: `config :pleroma, :fe` in favor of the more flexible `config :pleroma, :frontend_configurations`

## [0.9.99999] - 2019-05-31
### Security
- Mastodon API: Fix lists leaking private posts

## [0.9.9999] - 2019-04-05
### Security
- Mastodon API: Fix content warnings skipping HTML sanitization

## [0.9.999] - 2019-03-13
Frontend changes only.
### Added
- Added floating action button for posting status on mobile
### Changed
- Changed user-settings icon to a pencil
### Fixed
- Keyboard shortcuts activating when typing a message
- Gaps when scrolling down on a timeline after showing new

## [0.9.99] - 2019-03-08
### Changed
- Update the frontend to the 0.9.99 tag
### Fixed
- Sign the date header in federation to fix Mastodon federation.

## [0.9.9] - 2019-02-22
This is our first stable release.
