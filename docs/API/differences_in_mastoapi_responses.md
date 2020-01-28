# Differences in Mastodon API responses from vanilla Mastodon

A Pleroma instance can be identified by "<Mastodon version> (compatible; Pleroma <version>)" present in `version` field in response from `/api/v1/instance`

## Flake IDs

Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However just like Mastodon's ids they are sortable strings

## Attachment cap

Some apps operate under the assumption that no more than 4 attachments can be returned or uploaded. Pleroma however does not enforce any limits on attachment count neither when returning the status object nor when posting.

## Timelines

Adding the parameter `with_muted=true` to the timeline queries will also return activities by muted (not by blocked!) users.
Adding the parameter `exclude_visibilities` to the timeline queries will exclude the statuses with the given visibilities. The parameter accepts an array of visibility types (`public`, `unlisted`, `private`, `direct`), e.g., `exclude_visibilities[]=direct&exclude_visibilities[]=private`.

## Statuses

- `visibility`: has an additional possible value `list`

Has these additional fields under the `pleroma` object:

- `local`: true if the post was made on the local instance
- `conversation_id`: the ID of the AP context the status is associated with (if any)
- `direct_conversation_id`: the ID of the Mastodon direct message conversation the status is associated with (if any)
- `in_reply_to_account_acct`: the `acct` property of User entity for replied user (if any)
- `content`: a map consisting of alternate representations of the `content` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`
- `spoiler_text`: a map consisting of alternate representations of the `spoiler_text` property with the key being it's mimetype. Currently the only alternate representation supported is `text/plain`
- `expires_at`: a datetime (iso8601) that states when the post will expire (be deleted automatically), or empty if the post won't expire
- `thread_muted`: true if the thread the post belongs to is muted
- `emoji_reactions`: A list with emoji / reaction maps. The format is {emoji: "☕", count: 1}. Contains no information about the reacting users, for that use the `emoji_reactions_by` endpoint.

## Attachments

Has these additional fields under the `pleroma` object:

- `mime_type`: mime type of the attachment.

## Accounts

The `id` parameter can also be the `nickname` of the user. This only works in these endpoints, not the deeper nested ones for following etc.

- `/api/v1/accounts/:id`
- `/api/v1/accounts/:id/statuses`

Has these additional fields under the `pleroma` object:

- `tags`: Lists an array of tags for the user
- `relationship{}`: Includes fields as documented for Mastodon API https://docs.joinmastodon.org/entities/relationship/
- `is_moderator`: boolean, nullable,  true if user is a moderator
- `is_admin`: boolean, nullable, true if user is an admin
- `confirmation_pending`: boolean, true if a new user account is waiting on email confirmation to be activated
- `hide_followers`: boolean, true when the user has follower hiding enabled
- `hide_follows`: boolean, true when the user has follow hiding enabled
- `hide_followers_count`: boolean, true when the user has follower stat hiding enabled
- `hide_follows_count`: boolean, true when the user has follow stat hiding enabled
- `settings_store`: A generic map of settings for frontends. Opaque to the backend. Only returned in `verify_credentials` and `update_credentials`
- `chat_token`: The token needed for Pleroma chat. Only returned in `verify_credentials`
- `deactivated`: boolean, true when the user is deactivated
- `allow_following_move`: boolean, true when the user allows automatically follow moved following accounts
- `unread_conversation_count`: The count of unread conversations. Only returned to the account owner.

### Source

Has these additional fields under the `pleroma` object:

- `show_role`: boolean, nullable, true when the user wants his role (e.g admin, moderator) to be shown
- `no_rich_text` - boolean, nullable, true when html tags are stripped from all statuses requested from the API
- `discoverable`: boolean, true when the user allows discovery of the account in search results and other services.
- `actor_type`: string, the type of this account.

## Conversations

Has an additional field under the `pleroma` object:

- `recipients`: The list of the recipients of this Conversation. These will be addressed when replying to this conversation.

## GET `/api/v1/conversations`

Accepts additional parameters:

- `recipients`: Only return conversations with the given recipients (a list of user ids). Usage example: `GET /api/v1/conversations?recipients[]=1&recipients[]=2`

## Account Search

Behavior has changed:

- `/api/v1/accounts/search`: Does not require authentication


## Notifications

Has these additional fields under the `pleroma` object:

- `is_seen`: true if the notification was read by the user

### Move Notification

The `type` value is `move`. Has an additional field:

- `target`: new account

### EmojiReaction Notification

The `type` value is `pleroma:emoji_reaction`. Has these fields:

- `emoji`: The used emoji
- `account`: The account of the user who reacted
- `status`: The status that was reacted on

## GET `/api/v1/notifications`

Accepts additional parameters:

- `exclude_visibilities`: will exclude the notifications for activities with the given visibilities. The parameter accepts an array of visibility types (`public`, `unlisted`, `private`, `direct`). Usage example: `GET /api/v1/notifications?exclude_visibilities[]=direct&exclude_visibilities[]=private`.
- `with_move`: boolean, when set to `true` will include Move notifications. `false` by default.

## POST `/api/v1/statuses`

Additional parameters can be added to the JSON body/Form data:

- `preview`: boolean, if set to `true` the post won't be actually posted, but the status entitiy would still be rendered back. This could be useful for previewing rich text/custom emoji, for example.
- `content_type`: string, contain the MIME type of the status, it is transformed into HTML by the backend. You can get the list of the supported MIME types with the nodeinfo endpoint.
- `to`: A list of nicknames (like `lain@soykaf.club` or `lain` on the local server) that will be used to determine who is going to be addressed by this post. Using this will disable the implicit addressing by mentioned names in the `status` body, only the people in the `to` list will be addressed. The normal rules for for post visibility are not affected by this and will still apply.
- `visibility`: string, besides standard MastoAPI values (`direct`, `private`, `unlisted` or `public`) it can be used to address a List by setting it to `list:LIST_ID`.
- `expires_in`: The number of seconds the posted activity should expire in. When a posted activity expires it will be deleted from the server, and a delete request for it will be federated. This needs to be longer than an hour.
- `in_reply_to_conversation_id`: Will reply to a given conversation, addressing only the people who are part of the recipient set of that conversation. Sets the visibility to `direct`.

## GET `/api/v1/statuses`

An endpoint to get multiple statuses by IDs.

Required parameters:

- `ids`: array of activity ids

Usage example: `GET /api/v1/statuses/?ids[]=1&ids[]=2`.

Returns: array of Status.

The maximum number of statuses is limited to 100 per request.

## PATCH `/api/v1/update_credentials`

Additional parameters can be added to the JSON body/Form data:

- `no_rich_text` - if true, html tags are stripped from all statuses requested from the API
- `hide_followers` - if true, user's followers will be hidden
- `hide_follows` - if true, user's follows will be hidden
- `hide_followers_count` - if true, user's follower count will be hidden
- `hide_follows_count` - if true, user's follow count will be hidden
- `hide_favorites` - if true, user's favorites timeline will be hidden
- `show_role` - if true, user's role (e.g admin, moderator) will be exposed to anyone in the API
- `default_scope` - the scope returned under `privacy` key in Source subentity
- `pleroma_settings_store` - Opaque user settings to be saved on the backend.
- `skip_thread_containment` - if true, skip filtering out broken threads
- `allow_following_move` - if true, allows automatically follow moved following accounts
- `pleroma_background_image` - sets the background image of the user.
- `discoverable` - if true, discovery of this account in search results and other services is allowed.
- `actor_type` - the type of this account.

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
