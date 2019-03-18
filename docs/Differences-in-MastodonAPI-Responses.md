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

## Notifications

Has these additional fields under the `pleroma` object:

- `is_seen`: true if the notification was read by the user
