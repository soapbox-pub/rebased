# Differences in Mastodon API responses from vanilla Mastodon

A Pleroma instance can be identified by "<Mastodon version> (compatible; Pleroma <version>)" present in `version` field in response from `/api/v1/instance`

## Flake IDs

Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However just like Mastodon's ids they are sortable strings

## Attachment cap

Some apps operate under the assumption that no more than 4 attachments can be returned or uploaded. Pleroma however does not enforce any limits on attachment count neither when returning the status object nor when posting.

## Timelines

Adding the parameter `with_muted=true` to the timeline queries will also return activities by muted (not by blocked!) users.

## Statuses

Has these additional fields under the `pleroma` object:

- `local`: true if the post was made on the local instance.
- `conversation_id`: the ID of the conversation the status is associated with (if any)
- `in_reply_to_account_acct`: the `acct` property of User entity for replied user (if any)
- `content`: a map consisting of alternate representations of the `content` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`
- `spoiler_text`: a map consisting of alternate representations of the `spoiler_text` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`

## Attachments

Has these additional fields under the `pleroma` object:

- `mime_type`: mime type of the attachment.

## Accounts

- `/api/v1/accounts/:id`: The `id` parameter can also be the `nickname` of the user. This only works in this endpoint, not the deeper nested ones for following etc.

Has these additional fields under the `pleroma` object:

- `tags`: Lists an array of tags for the user
- `relationship{}`: Includes fields as documented for Mastodon API https://docs.joinmastodon.org/api/entities/#relationship
- `is_moderator`: boolean, nullable,  true if user is a moderator
- `is_admin`: boolean, nullable, true if user is an admin
- `confirmation_pending`: boolean, true if a new user account is waiting on email confirmation to be activated
- `hide_followers`: boolean, true when the user has follower hiding enabled
- `hide_follows`: boolean, true when the user has follow hiding enabled
- `settings_store`: A generic map of settings for frontends. Opaque to the backend. Only returned in `verify_credentials` and `update_credentials`

### Source

Has these additional fields under the `pleroma` object:

- `show_role`: boolean, nullable, true when the user wants his role (e.g admin, moderator) to be shown
- `no_rich_text` - boolean, nullable, true when html tags are stripped from all statuses requested from the API

## Account Search

Behavior has changed:

- `/api/v1/accounts/search`: Does not require authentication

## Notifications

Has these additional fields under the `pleroma` object:

- `is_seen`: true if the notification was read by the user

## POST `/api/v1/statuses`

Additional parameters can be added to the JSON body/Form data:

- `preview`: boolean, if set to `true` the post won't be actually posted, but the status entitiy would still be rendered back. This could be useful for previewing rich text/custom emoji, for example.
- `content_type`: string, contain the MIME type of the status, it is transformed into HTML by the backend. You can get the list of the supported MIME types with the nodeinfo endpoint.

## PATCH `/api/v1/update_credentials`

Additional parameters can be added to the JSON body/Form data:

- `no_rich_text` - if true, html tags are stripped from all statuses requested from the API
- `hide_followers` - if true, user's followers will be hidden
- `hide_follows` - if true, user's follows will be hidden
- `hide_favorites` - if true, user's favorites timeline will be hidden
- `show_role` - if true, user's role (e.g admin, moderator) will be exposed to anyone in the API
- `default_scope` - the scope returned under `privacy` key in Source subentity
- `pleroma_settings_store` - Opaque user settings to be saved on the backend.
- `skip_thread_containment` - if true, skip filtering out broken threads

### Pleroma Settings Store
Pleroma has mechanism that allows frontends to save blobs of json for each user on the backend. This can be used to save frontend-specific settings for a user that the backend does not need to know about.

The parameter should have a form of `{frontend_name: {...}}`, with `frontend_name` identifying your type of client, e.g. `pleroma_fe`. It will overwrite everything under this property, but will not overwrite other frontend's settings.

This information is returned in the `verify_credentials` endpoint.

## Authentication

*Pleroma supports refreshing tokens.

`POST /oauth/token`
Post here request with grant_type=refresh_token to obtain new access token. Returns an access token.

## Account Registration
`POST /api/v1/accounts`

Has theses additionnal parameters (which are the same as in Pleroma-API):
    * `fullname`: optional
    * `bio`: optional
    * `captcha_solution`: optional, contains provider-specific captcha solution,
    * `captcha_token`: optional, contains provider-specific captcha token
    * `token`: invite token required when the registerations aren't public.
