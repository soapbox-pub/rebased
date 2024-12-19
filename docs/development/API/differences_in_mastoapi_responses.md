# Differences in Mastodon API responses from vanilla Mastodon

A Pleroma instance can be identified by "<Mastodon version> (compatible; Pleroma <version>)" present in `version` field in response from `/api/v1/instance` and `/api/v2/instance`

## Flake IDs

Pleroma uses 128-bit ids as opposed to Mastodon's 64 bits. However, just like Mastodon's ids, they are lexically sortable strings

## Timelines

Adding the parameter `with_muted=true` to the timeline queries will also return activities by muted (not by blocked!) users.

Adding the parameter `exclude_visibilities` to the timeline queries will exclude the statuses with the given visibilities. The parameter accepts an array of visibility types (`public`, `unlisted`, `private`, `direct`), e.g., `exclude_visibilities[]=direct&exclude_visibilities[]=private`.

Adding the parameter `reply_visibility` to the public and home timelines queries will filter replies. Possible values: without parameter (default) shows all replies, `following` - replies directed to you or users you follow, `self` - replies directed to you.

Adding the parameter `instance=lain.com` to the public timeline will show only statuses originating from `lain.com` (or any remote instance).

Home, public, hashtag & list timelines accept these parameters:

- `only_media`: show only statuses with media attached
- `local`: show only local statuses
- `remote`: show only remote statuses

## Statuses

- `visibility`: has additional possible values `list` and `local` (for local-only statuses)

Has these additional fields under the `pleroma` object:

- `local`: true if the post was made on the local instance
- `conversation_id`: the ID of the AP context the status is associated with (if any)
- `direct_conversation_id`: the ID of the Mastodon direct message conversation the status is associated with (if any)
- `in_reply_to_account_acct`: the `acct` property of User entity for replied user (if any)
- `content`: a map consisting of alternate representations of the `content` property with the key being its mimetype. Currently, the only alternate representation supported is `text/plain`
- `spoiler_text`: a map consisting of alternate representations of the `spoiler_text` property with the key being its mimetype. Currently, the only alternate representation supported is `text/plain`
- `expires_at`: a datetime (iso8601) that states when the post will expire (be deleted automatically), or empty if the post won't expire
- `thread_muted`: true if the thread the post belongs to is muted
- `emoji_reactions`: A list with emoji / reaction maps. The format is `{name: "☕", count: 1, me: true}`. Contains no information about the reacting users, for that use the `/statuses/:id/reactions` endpoint.
- `parent_visible`: If the parent of this post is visible to the user or not.
- `pinned_at`: a datetime (iso8601) when status was pinned, `null` otherwise.
- `quotes_count`: the count of status quotes.
- `non_anonymous`: true if the source post specifies the poll results are not anonymous. Currently only implemented by Smithereen.
- `bookmark_folder`: the ID of the folder bookmark is stored within (if any).
- `list_id`: the ID of the list the post is addressed to (if any, only returned to author).

The `GET /api/v1/statuses/:id/source` endpoint additionally has the following attributes:

- `content_type`: The content type of the status source.

## Scheduled statuses

Has these additional fields in `params`:

- `expires_in`: the number of seconds the posted activity should expire in.

## Media Attachments

Has these additional fields under the `pleroma` object:

- `mime_type`: mime type of the attachment.

### Attachment cap

Some apps operate under the assumption that no more than 4 attachments can be returned or uploaded. Pleroma however does not enforce any limits on attachment count neither when returning the status object nor when posting.

### Limitations

Pleroma does not process remote images and therefore cannot include fields such as `meta` and `blurhash`. It does not support focal points or aspect ratios. The frontend is expected to handle it.

## Bookmarks

The `GET /api/v1/bookmarks` endpoint accepts optional parameter `folder_id` for bookmark folder ID.

The `POST /api/v1/statuses/:id/bookmark` endpoint accepts optional parameter `folder_id` for bookmark folder ID.

## Accounts

The `id` parameter can also be the `nickname` of the user. This only works in these endpoints, not the deeper nested ones for following etc.

- `/api/v1/accounts/:id`
- `/api/v1/accounts/:id/statuses`

`/api/v1/accounts/:id/statuses` endpoint accepts these parameters:

- `pinned`: include only pinned statuses
- `tagged`: with tag
- `only_media`: include only statuses with media attached
- `with_muted`: include statuses/reactions from muted accounts
- `exclude_reblogs`: exclude reblogs
- `exclude_replies`: exclude replies
- `exclude_visibilities`: exclude visibilities

Endpoints which accept `with_relationships` parameter:

- `/api/v1/accounts/:id`
- `/api/v1/accounts/:id/followers`
- `/api/v1/accounts/:id/following`
- `/api/v1/mutes`

Has these additional fields under the `pleroma` object:

- `ap_id`: nullable URL string, ActivityPub id of the user
- `background_image`: nullable URL string, background image of the user
- `tags`: Lists an array of tags for the user
- `relationship` (object): Includes fields as documented for Mastodon API https://docs.joinmastodon.org/entities/relationship/
- `is_moderator`: boolean, nullable, true if user is a moderator
- `is_admin`: boolean, nullable, true if user is an admin
- `confirmation_pending`: boolean, true if a new user account is waiting on email confirmation to be activated
- `hide_favorites`: boolean, true when the user has hiding favorites enabled
- `hide_followers`: boolean, true when the user has follower hiding enabled
- `hide_follows`: boolean, true when the user has follow hiding enabled
- `hide_followers_count`: boolean, true when the user has follower stat hiding enabled
- `hide_follows_count`: boolean, true when the user has follow stat hiding enabled
- `settings_store`: A generic map of settings for frontends. Opaque to the backend. Only returned in `/api/v1/accounts/verify_credentials` and `/api/v1/accounts/update_credentials`
- `chat_token`: The token needed for Pleroma shoutbox. Only returned in `/api/v1/accounts/verify_credentials`
- `deactivated`: boolean, true when the user is deactivated
- `allow_following_move`: boolean, true when the user allows automatically follow moved following accounts
- `unread_conversation_count`: The count of unread conversations. Only returned to the account owner.
- `unread_notifications_count`: The count of unread notifications. Only returned to the account owner.
- `notification_settings`: object, can be absent. See `/api/v1/pleroma/notification_settings` for the parameters/keys returned.
- `accepts_chat_messages`: boolean, but can be null if we don't have that information about a user
- `favicon`: nullable URL string, Favicon image of the user's instance
- `avatar_description`: string, image description for user avatar, defaults to empty string
- `header_description`: string, image description for user banner, defaults to empty string

### Source

Has these additional fields under the `pleroma` object:

- `show_role`: boolean, nullable, true when the user wants his role (e.g admin, moderator) to be shown
- `no_rich_text` - boolean, nullable, true when html tags are stripped from all statuses requested from the API
- `discoverable`: boolean, true when the user allows external services (search bots) etc. to index / list the account (regardless of this setting, user will still appear in regular search results)
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

## Search (global)

Unlisted posts are available in search results, they are considered to be public posts that shouldn't be shown in local/federated timeline.

## Notifications

Has these additional fields under the `pleroma` object:

- `is_seen`: true if the notification was read by the user

### Move Notification

The `type` value is `move`. Has an additional field:

- `target`: new account

### EmojiReact Notification

The `type` value is `pleroma:emoji_reaction`. Has these fields:

- `emoji`: The used emoji
- `account`: The account of the user who reacted
- `status`: The status that was reacted on

### ChatMention Notification (not default)

This notification has to be requested explicitly.

The `type` value is `pleroma:chat_mention`

- `account`: The account who sent the message
- `chat_message`: The chat message

### Report Notification (not default)

This notification has to be requested explicitly.

The `type` value is `pleroma:report`

- `account`: The account who reported
- `report`: The report

## GET `/api/v1/notifications`

Accepts additional parameters:

- `exclude_visibilities`: will exclude the notifications for activities with the given visibilities. The parameter accepts an array of visibility types (`public`, `unlisted`, `private`, `direct`). Usage example: `GET /api/v1/notifications?exclude_visibilities[]=direct&exclude_visibilities[]=private`.
- `include_types`: will include the notifications for activities with the given types. The parameter accepts an array of types (`mention`, `follow`, `reblog`, `favourite`, `move`, `pleroma:emoji_reaction`, `pleroma:chat_mention`, `pleroma:report`). Usage example: `GET /api/v1/notifications?include_types[]=mention&include_types[]=reblog`.

## DELETE `/api/v1/notifications/destroy_multiple`

An endpoint to delete multiple statuses by IDs.

Required parameters:

- `ids`: array of activity ids

Usage example: `DELETE /api/v1/notifications/destroy_multiple/?ids[]=1&ids[]=2`.

Returns on success: 200 OK `{}`

## POST `/api/v1/statuses`

Additional parameters can be added to the JSON body/Form data:

- `preview`: boolean, if set to `true` the post won't be actually posted, but the status entity would still be rendered back. This could be useful for previewing rich text/custom emoji, for example.
- `content_type`: string, contain the MIME type of the status, it is transformed into HTML by the backend. You can get the list of the supported MIME types with the nodeinfo endpoint.
- `to`: A list of nicknames (like `lain@soykaf.club` or `lain` on the local server) that will be used to determine who is going to be addressed by this post. Using this will disable the implicit addressing by mentioned names in the `status` body, only the people in the `to` list will be addressed. The normal rules for post visibility are not affected by this and will still apply.
- `visibility`: string, besides standard MastoAPI values (`direct`, `private`, `unlisted`, `local` or `public`) it can be used to address a List by setting it to `list:LIST_ID`.
- `expires_in`: The number of seconds the posted activity should expire in. When a posted activity expires it will be deleted from the server, and a delete request for it will be federated. This needs to be longer than an hour.
- `in_reply_to_conversation_id`: Will reply to a given conversation, addressing only the people who are part of the recipient set of that conversation. Sets the visibility to `direct`.

## GET `/api/v1/statuses`

An endpoint to get multiple statuses by IDs.

Required parameters:

- `ids`: array of activity ids

Usage example: `GET /api/v1/statuses/?ids[]=1&ids[]=2`.

Returns: array of Status.

The maximum number of statuses is limited to 100 per request.

## PATCH `/api/v1/accounts/update_credentials`

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
- `also_known_as` - array of ActivityPub IDs, needed for following move
- `pleroma_background_image` - sets the background image of the user. Can be set to "" (an empty string) to reset.
- `discoverable` - if true, external services (search bots) etc. are allowed to index / list the account (regardless of this setting, user will still appear in regular search results).
- `actor_type` - the type of this account.
- `accepts_chat_messages` - if false, this account will reject all chat messages.
- `language` - user's preferred language for receiving emails (digest, confirmation, etc.)
- `avatar_description` - image description for user avatar
- `header_description` - image description for user banner

All images (avatar, banner and background) can be reset to the default by sending an empty string ("") instead of a file.

### Pleroma Settings Store

Pleroma has mechanism that allows frontends to save blobs of json for each user on the backend. This can be used to save frontend-specific settings for a user that the backend does not need to know about.

The parameter should have a form of `{frontend_name: {...}}`, with `frontend_name` identifying your type of client, e.g. `pleroma_fe`. It will overwrite everything under this property, but will not overwrite other frontend's settings.

This information is returned in the `/api/v1/accounts/verify_credentials` endpoint.

## Authentication

*Pleroma supports refreshing tokens.*

### POST `/oauth/token`

You can obtain access tokens for a user in a few additional ways.

#### Refreshing a token

To obtain a new access token from a refresh token, pass `grant_type=refresh_token` with the following extra parameters:

- `refresh_token`: The refresh token.

#### Getting a token with a password

To obtain a token from a user's password, pass `grant_type=password` with the following extra parameters:

- `username`: Username to authenticate.
- `password`: The user's password.

#### Response body

Additional fields are returned in the response:

- `id`: The primary key of this token in Pleroma's database.
- `me` (user tokens only): The ActivityPub ID of the user who owns the token.

## Account Registration

`POST /api/v1/accounts`

Has these additional parameters (which are the same as in Pleroma-API):

- `fullname`: optional
- `bio`: optional
- `captcha_solution`: optional, contains provider-specific captcha solution,
- `captcha_token`: optional, contains provider-specific captcha token
- `captcha_answer_data`: optional, contains provider-specific captcha data
- `token`: invite token required when the registrations aren't public.
- `language`: optional, user's preferred language for receiving emails (digest, confirmation, etc.), default to the language set in the `userLanguage` cookies or `Accept-Language` header.

## Instance

`GET /api/v1/instance` has additional fields

- `max_toot_chars`: The maximum characters per post
- `max_media_attachments`: Maximum number of post media attachments
- `chat_limit`: The maximum characters per chat message
- `description_limit`: The maximum characters per image description
- `poll_limits`: The limits of polls
- `shout_limit`: The maximum characters per Shoutbox message
- `upload_limit`: The maximum upload file size
- `avatar_upload_limit`: The same for avatars
- `background_upload_limit`: The same for backgrounds
- `banner_upload_limit`: The same for banners
- `background_image`: A background image that frontends can use
- `pleroma.metadata.account_activation_required`: Whether users are required to confirm their emails before signing in
- `pleroma.metadata.birthday_required`: Whether users are required to provide their birth day when signing in
- `pleroma.metadata.birthday_min_age`: The minimum user age (in days)
- `pleroma.metadata.features`: A list of supported features
- `pleroma.metadata.federation`: The federation restrictions of this instance
- `pleroma.metadata.fields_limits`: A list of values detailing the length and count limitation for various instance-configurable fields.
- `pleroma.metadata.post_formats`: A list of the allowed post format types
- `pleroma.stats.mau`: Monthly active user count
- `pleroma.vapid_public_key`: The public key needed for push messages

In, `GET /api/v2/instance` Pleroma-specific fields are all moved into `pleroma` object. `max_toot_chars`, `poll_limits` and `upload_limit` are replaced with their MastoAPI counterparts.

## Push Subscription

`POST /api/v1/push/subscription`
`PUT /api/v1/push/subscription`

Permits these additional alert types:

- pleroma:chat_mention
- pleroma:emoji_reaction

## Markers

Has these additional fields under the `pleroma` object:

- `unread_count`: contains number unread notifications

## Streaming

### Chats

There is an additional `user:pleroma_chat` stream. Incoming chat messages will make the current chat be sent to this `user` stream. The `event` of an incoming chat message is `pleroma:chat_update`. The payload is the updated chat with the incoming chat message in the `last_message` field.

### Remote timelines

For viewing remote server timelines, there are `public:remote` and `public:remote:media` streams. Each of these accept a parameter like `?instance=lain.com`.

### Follow relationships updates

Pleroma streams follow relationships updates as `pleroma:follow_relationships_update` events to the `user` stream.

The message payload consist of:

- `state`: a relationship state, one of `follow_pending`, `follow_accept` or `follow_reject`.

- `follower` and `following` maps with following fields:
  - `id`: user ID
  - `follower_count`: follower count
  - `following_count`: following count

### Authenticating via `sec-websocket-protocol` header

Pleroma allows to authenticate via the `sec-websocket-protocol` header, for example, if your access token is `your-access-token`, you can authenticate using the following:

```
sec-websocket-protocol: your-access-token
```

### Authenticating after connection via `pleroma:authenticate` event

Pleroma allows to authenticate after connection is established, via the `pleroma:authenticate` event. For example, if your access token is `your-access-token`, you can send the following after the connection is established:

```
{"type": "pleroma:authenticate", "token": "your-access-token"}
```

### Response to client-sent events

Pleroma will respond to client-sent events that it recognizes. Supported event types are:

- `subscribe`
- `unsubscribe`
- `pleroma:authenticate`

The reply will be in the following format:

```
{
  "event": "pleroma:respond",
  "payload": "{\"type\": \"<type of the client-sent event>\", \"result\": \"<result of the action>\", \"error\": \"<error code>\"}"
}
```

Result of the action can be either `success`, `ignored` or `error`. If it is `error`, the `error` property will contain the error code. Otherwise, the `error` property will not be present. Below are some examples:

```
{
  "event": "pleroma:respond",
  "payload": "{\"type\": \"pleroma:authenticate\", \"result\": \"success\"}"
}

{
  "event": "pleroma:respond",
  "payload": "{\"type\": \"subscribe\", \"result\": \"ignored\"}"
}

{
  "event": "pleroma:respond",
  "payload": "{\"type\": \"unsubscribe\", \"result\": \"error\", \"error\": \"bad_topic\"}"
}
```

If the sent event is not of a type that Pleroma supports, it will not reply.

### The `stream` attribute of a server-sent event

Technically, this is in Mastodon, but its documentation does nothing to specify its format.

This attribute appears on every event type except `pleroma:respond` and `delete`. It helps clients determine where they should display the new statuses.

The value of the attribute is an array containing one or two elements. The first element is the type of the stream. The second is the identifier related to that specific stream, if applicable.

For the following stream types, there is a second element in the array:

- `list`: The second element is the id of the list, as a string.
- `hashtag`: The second element is the name of the hashtag.
- `public:remote:media` and `public:remote`: The second element is the domain of the corresponding instance.

For all other stream types, there is no second element.

Some examples of valid `stream` values:

- `["list", "1"]`: List of id 1.
- `["hashtag", "mew"]`: The hashtag #mew.
- `["user:notifications"]`: Notifications for the current user.
- `["user"]`: Home timeline.
- `["public:remote", "mew.moe"]`: Public posts from the instance mew.moe .

### The unified streaming endpoint

If you do not specify a stream to connect to when requesting `/api/v1/streaming`, you will enter a connection that subscribes to no streams. After the connection is established, you can authenticate and then subscribe to different streams.

### List of supported streams

Below is a list of supported streams by Pleroma. To make a single-stream WebSocket connection, append the string specified in "Query style" to the streaming endpoint url.
To subscribe to a stream after the connection is established, merge the JSON object specified in "Subscribe style" with `{"type": "subscribe"}`. To unsubscribe, merge it with `{"type": "unsubscribe"}`.

For example, to receive updates on the list 1, you can connect to `/api/v1/streaming/?stream=list&list=1`, or send

```
{"type": "subscribe", "stream": "list", "list": "1"}
```

upon establishing the websocket connection.

To unsubscribe to list 1, send

```
{"type": "unsubscribe", "stream": "list", "list": "1"}
```

Note that if you specify a stream that requires a logged-in user in the query string (for example, `user` or `list`), you have to specify the access token when you are trying to establish the connection, i.e. in the query string or via the `sec-websocket-protocol` header.

- `list`
  - Query style: `?stream=list&list=<id>`
  - Subscribe style: `{"stream": "list", "list": "<id>"}`
- `public`, `public:local`, `public:media`, `public:local:media`, `user`, `user:pleroma_chat`, `user:notifications`, `direct`
  - Query style: `?stream=<stream name>`
  - Subscribe style: `{"stream": "<stream name>"}`
- `hashtag`
  - Query style: `?stream=hashtag&tag=<name>`
  - Subscribe style: `{"stream": "hashtag", "tag": "<name>"}`
- `public:remote`, `public:remote:media`
  - Query style: `?stream=<stream name>&instance=<instance domain>`
  - Subscribe style: `{"stream": "<stream name>", "instance": "<instance domain>"}`

## User muting and thread muting

Both user muting and thread muting can be done for only a certain time by adding an `expires_in` parameter to the API calls and giving the expiration time in seconds.

## Not implemented

Pleroma is generally compatible with the Mastodon 2.7.2 API, but some newer features and non-essential features are omitted. These features usually return an HTTP 200 status code, but with an empty response. While they may be added in the future, they are considered low priority.

### Suggestions

*Added in Mastodon 2.4.3*

- `GET /api/v1/suggestions`: Returns an empty array, `[]`

### Trends

*Added in Mastodon 3.0.0*

- `GET /api/v1/trends`: Returns an empty array, `[]`

### Featured tags

*Added in Mastodon 3.0.0*

- `GET /api/v1/featured_tags`: Returns HTTP 404
