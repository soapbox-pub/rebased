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
- `is_moderator`: boolean, true if user is a moderator
- `is_admin`: boolean, true if user is an admin
- `confirmation_pending`: boolean, true if a new user account is waiting on email confirmation to be activated

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
