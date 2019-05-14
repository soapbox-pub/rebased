# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [unreleased]
### Added
- LDAP authentication
- External OAuth provider authentication
- A [job queue](https://git.pleroma.social/pleroma/pleroma_job_queue) for federation, emails, web push, etc.
- [Prometheus](https://prometheus.io/) metrics
- Support for Mastodon's remote interaction
- Mix Tasks: `mix pleroma.database remove_embedded_objects`
- Federation: Support for reports
- Configuration: `safe_dm_mentions` option
- Configuration: `link_name` option
- Configuration: `fetch_initial_posts` option
- Configuration: `notify_email` option
- Configuration: Media proxy `whitelist` option
- Pleroma API: User subscriptions
- Pleroma API: Healthcheck endpoint
- Admin API: Endpoints for listing/revoking invite tokens
- Admin API: Endpoints for making users follow/unfollow each other
- Admin API: added filters (role, tags, email, name) for users endpoint
- Mastodon API: [Scheduled statuses](https://docs.joinmastodon.org/api/rest/scheduled-statuses/)
- Mastodon API: `/api/v1/notifications/destroy_multiple` (glitch-soc extension)
- Mastodon API: `/api/v1/pleroma/accounts/:id/favourites` (API extension)
- Mastodon API: [Reports](https://docs.joinmastodon.org/api/rest/reports/)
- Mastodon API: REST API for creating an account
- ActivityPub C2S: OAuth endpoints
- Metadata RelMe provider
- OAuth: added support for refresh tokens
- Emoji packs and emoji pack manager
- AdminFE: initial release with basic user management accessible at /pleroma/admin/
- Addressable lists

### Changed
- **Breaking:** Configuration: move from Pleroma.Mailer to Pleroma.Emails.Mailer
- Enforcement of OAuth scopes
- Add multiple use/time expiring invite token
- Restyled OAuth pages to fit with Pleroma's default theme
- Link/mention/hashtag detection is now handled by [auto_linker](https://git.pleroma.social/pleroma/auto_linker)
- NodeInfo: Return `safe_dm_mentions` feature flag
- Federation: Expand the audience of delete activities to all recipients of the deleted object
- Federation: Removed `inReplyToStatusId` from objects
- Configuration: Dedupe enabled by default
- Configuration: Added `extra_cookie_attrs` for setting non-standard cookie attributes. Defaults to ["SameSite=Lax"] so that remote follows work.
- Pleroma API: Support for emoji tags in `/api/pleroma/emoji` resulting in a breaking API change
- Timelines: Messages involving people you have blocked will be excluded from the timeline in all cases instead of just repeats.
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
- Admin API: Move the user related API to `api/pleroma/admin/users`

### Fixed
- Added an FTS index on objects. Running `vacuum analyze` and setting a larger `work_mem` is recommended.
- Followers counter not being updated when a follower is blocked
- Deactivated users being able to request an access token
- Limit on request body in rich media/relme parsers being ignored resulting in a possible memory leak
- proper Twitter Card generation instead of a dummy
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
