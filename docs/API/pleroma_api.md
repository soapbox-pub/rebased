# Pleroma API

Requests that require it can be authenticated with [an OAuth token](https://tools.ietf.org/html/rfc6749), the `_pleroma_key` cookie, or [HTTP Basic Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization).

Request parameters can be passed via [query strings](https://en.wikipedia.org/wiki/Query_string) or as [form data](https://www.w3.org/TR/html401/interact/forms.html). Files must be uploaded as `multipart/form-data`.

## `/api/pleroma/emoji`
### Lists the custom emoji on that server.
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
{
  "girlpower": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/girlpower-128.png"
  },
  "education": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/education-128.png"
  },
  "finnishlove": {
    "tags": [
      "Finmoji"
    ],
    "image_url": "/finmoji/128px/finnishlove-128.png"
  }
}
```
* Note: Same data as Mastodon API’s `/api/v1/custom_emojis` but in a different format

## `/api/pleroma/follow_import`
### Imports your follows, for example from a Mastodon CSV file.
* Method: `POST`
* Authentication: required
* Params:
    * `list`: STRING or FILE containing a whitespace-separated list of accounts to follow
* Response: HTTP 200 on success, 500 on error
* Note: Users that can't be followed are silently skipped.

## `/api/pleroma/captcha`
### Get a new captcha
* Method: `GET`
* Authentication: not required
* Params: none
* Response: Provider specific JSON, the only guaranteed parameter is `type`
* Example response: `{"type": "kocaptcha", "token": "whatever", "url": "https://captcha.kotobank.ch/endpoint"}`

## `/api/pleroma/delete_account`
### Delete an account
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
* Response: JSON. Returns `{"status": "success"}` if the deletion was successful, `{"error": "[error message]"}` otherwise
* Example response: `{"error": "Invalid password."}`

## `/api/pleroma/disable_account`
### Disable an account
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
* Response: JSON. Returns `{"status": "success"}` if the account was successfully disabled, `{"error": "[error message]"}` otherwise
* Example response: `{"error": "Invalid password."}`

## `/api/pleroma/admin/`…
See [Admin-API](admin_api.md)

## `/api/v1/pleroma/notifications/read`
### Mark notifications as read
* Method `POST`
* Authentication: required
* Params (mutually exclusive):
    * `id`: a single notification id to read
    * `max_id`: read all notifications up to this id
* Response: Notification entity/Array of Notification entities that were read. In case of `max_id`, only the first 80 read notifications will be returned.

## `/api/v1/pleroma/accounts/:id/subscribe`
### Subscribe to receive notifications for all statuses posted by a user
* Method `POST`
* Authentication: required
* Params:
    * `id`: account id to subscribe to
* Response: JSON, returns a mastodon relationship object on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
{
  "id": "abcdefg",
  "following": true,
  "followed_by": false,
  "blocking": false,
  "muting": false,
  "muting_notifications": false,
  "subscribing": true,
  "requested": false,
  "domain_blocking": false,
  "showing_reblogs": true,
  "endorsed": false
}
```

## `/api/v1/pleroma/accounts/:id/unsubscribe`
### Unsubscribe to stop receiving notifications from user statuses
* Method `POST`
* Authentication: required
* Params:
    * `id`: account id to unsubscribe from
* Response: JSON, returns a mastodon relationship object on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
{
  "id": "abcdefg",
  "following": true,
  "followed_by": false,
  "blocking": false,
  "muting": false,
  "muting_notifications": false,
  "subscribing": false,
  "requested": false,
  "domain_blocking": false,
  "showing_reblogs": true,
  "endorsed": false
}
```

## `/api/v1/pleroma/accounts/:id/favourites`
### Returns favorites timeline of any user
* Method `GET`
* Authentication: not required
* Params:
    * `id`: the id of the account for whom to return results
    * `limit`: optional, the number of records to retrieve
    * `since_id`: optional, returns results that are more recent than the specified id
    * `max_id`: optional, returns results that are older than the specified id
* Response: JSON, returns a list of Mastodon Status entities on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
[
  {
    "account": {
      "id": "9hptFmUF3ztxYh3Svg",
      "url": "https://pleroma.example.org/users/nick2",
      "username": "nick2",
      ...
    },
    "application": {"name": "Web", "website": null},
    "bookmarked": false,
    "card": null,
    "content": "This is :moominmamma: note 0",
    "created_at": "2019-04-15T15:42:15.000Z",
    "emojis": [],
    "favourited": false,
    "favourites_count": 1,
    "id": "9hptFmVJ02khbzYJaS",
    "in_reply_to_account_id": null,
    "in_reply_to_id": null,
    "language": null,
    "media_attachments": [],
    "mentions": [],
    "muted": false,
    "pinned": false,
    "pleroma": {
      "content": {"text/plain": "This is :moominmamma: note 0"},
      "conversation_id": 13679,
      "local": true,
      "spoiler_text": {"text/plain": "2hu"}
    },
    "reblog": null,
    "reblogged": false,
    "reblogs_count": 0,
    "replies_count": 0,
    "sensitive": false,
    "spoiler_text": "2hu",
    "tags": [{"name": "2hu", "url": "/tag/2hu"}],
    "uri": "https://pleroma.example.org/objects/198ed2a1-7912-4482-b559-244a0369e984",
    "url": "https://pleroma.example.org/notice/9hptFmVJ02khbzYJaS",
    "visibility": "public"
  }
]
```

## `/api/v1/pleroma/accounts/update_*`
### Set and clear account avatar, banner, and background

- PATCH `/api/v1/pleroma/accounts/update_avatar`: Set/clear user avatar image
- PATCH `/api/v1/pleroma/accounts/update_banner`: Set/clear user banner image
- PATCH `/api/v1/pleroma/accounts/update_background`: Set/clear user background image

## `/api/v1/pleroma/accounts/confirmation_resend`
### Resend confirmation email
* Method `POST`
* Params:
    * `email`: email of that needs to be verified
* Authentication: not required
* Response: 204 No Content

## `/api/v1/pleroma/mascot`
### Gets user mascot image
* Method `GET`
* Authentication: required

* Response: JSON. Returns a mastodon media attachment entity.
* Example response:
```json
{
    "id": "abcdefg",
    "url": "https://pleroma.example.org/media/abcdefg.png",
    "type": "image",
    "pleroma": {
        "mime_type": "image/png"
    }
}
```

### Updates user mascot image
* Method `PUT`
* Authentication: required
* Params:
    * `image`: Multipart image
* Response: JSON. Returns a mastodon media attachment entity
  when successful, otherwise returns HTTP 415 `{"error": "error_msg"}`
* Example response:
```json
{
    "id": "abcdefg",
    "url": "https://pleroma.example.org/media/abcdefg.png",
    "type": "image",
    "pleroma": {
        "mime_type": "image/png"
    }
}
```
* Note: Behaves exactly the same as `POST /api/v1/upload`.
  Can only accept images - any attempt to upload non-image files will be met with `HTTP 415 Unsupported Media Type`.

## `/api/pleroma/notification_settings`
### Updates user notification settings
* Method `PUT`
* Authentication: required
* Params:
    * `followers`: BOOLEAN field, receives notifications from followers
    * `follows`: BOOLEAN field, receives notifications from people the user follows
    * `remote`: BOOLEAN field, receives notifications from people on remote instances
    * `local`: BOOLEAN field, receives notifications from people on the local instance
    * `privacy_option`: BOOLEAN field. When set to true, it removes the contents of a message from the push notification.
* Response: JSON. Returns `{"status": "success"}` if the update was successful, otherwise returns `{"error": "error_msg"}`

## `/api/pleroma/healthcheck`
### Healthcheck endpoint with additional system data.
* Method `GET`
* Authentication: not required
* Params: none
* Response: JSON, statuses (200 - healthy, 503 unhealthy).
* Example response:
```json
{
  "pool_size": 0, # database connection pool
  "active": 0, # active processes
  "idle": 0, # idle processes
  "memory_used": 0.00, # Memory used
  "healthy": true, # Instance state
  "job_queue_stats": {} # Job queue stats
}
```

## `/api/pleroma/change_email`
### Change account email
* Method `POST`
* Authentication: required
* Params:
    * `password`: user's password
    * `email`: new email
* Response: JSON. Returns `{"status": "success"}` if the change was successful, `{"error": "[error message]"}` otherwise
* Note: Currently, Mastodon has no API for changing email. If they add it in future it might be incompatible with Pleroma.

# Pleroma Conversations

Pleroma Conversations have the same general structure that Mastodon Conversations have. The behavior differs in the following ways when using these endpoints:

1. Pleroma Conversations never add or remove recipients, unless explicitly changed by the user.
2. Pleroma Conversations statuses can be requested by Conversation id.
3. Pleroma Conversations can be replied to.

Conversations have the additional field "recipients" under the "pleroma" key. This holds a list of all the accounts that will receive a message in this conversation.

The status posting endpoint takes an additional parameter, `in_reply_to_conversation_id`, which, when set, will set the visiblity to direct and address only the people who are the recipients of that Conversation.


## `GET /api/v1/pleroma/conversations/:id/statuses`
### Timeline for a given conversation
* Method `GET`
* Authentication: required
* Params: Like other timelines
* Response: JSON, statuses (200 - healthy, 503 unhealthy).

## `GET /api/v1/pleroma/conversations/:id`
### The conversation with the given ID.
* Method `GET`
* Authentication: required
* Params: None
* Response: JSON, statuses (200 - healthy, 503 unhealthy).

## `PATCH /api/v1/pleroma/conversations/:id`
### Update a conversation. Used to change the set of recipients.
* Method `PATCH`
* Authentication: required
* Params:
    * `recipients`: A list of ids of users that should receive posts to this conversation. This will replace the current list of recipients, so submit the full list. The owner of owner of the conversation will always be part of the set of recipients, though.
* Response: JSON, statuses (200 - healthy, 503 unhealthy)

## `GET /api/v1/pleroma/conversations/read`
### Marks all user's conversations as read.
* Method `POST`
* Authentication: required
* Params: None
* Response: JSON, returns a list of Mastodon Conversation entities that were marked as read (200 - healthy, 503 unhealthy).

## `GET /api/pleroma/emoji/packs`
### Lists the custom emoji packs on the server
* Method `GET`
* Authentication: not required
* Params: None
* Response: JSON, "ok" and 200 status and the JSON hashmap of "pack name" to "pack contents"

## `PUT /api/pleroma/emoji/packs/:name`
### Creates an empty custom emoji pack
* Method `PUT`
* Authentication: required
* Params: None
* Response: JSON, "ok" and 200 status or 409 if the pack with that name already exists

## `DELETE /api/pleroma/emoji/packs/:name`
### Delete a custom emoji pack
* Method `DELETE`
* Authentication: required
* Params: None
* Response: JSON, "ok" and 200 status or 500 if there was an error deleting the pack

## `POST /api/pleroma/emoji/packs/:name/update_file`
### Update a file in a custom emoji pack
* Method `POST`
* Authentication: required
* Params:
    * if the `action` is `add`, adds an emoji named `shortcode` to the pack `pack_name`,
      that means that the emoji file needs to be uploaded with the request
      (thus requiring it to be a multipart request) and be named `file`.
      There can also be an optional `filename` that will be the new emoji file name
      (if it's not there, the name will be taken from the uploaded file).
    * if the `action` is `update`, changes emoji shortcode
      (from `shortcode` to `new_shortcode` or moves the file (from the current filename to `new_filename`)
    * if the `action` is `remove`, removes the emoji named `shortcode` and it's associated file
* Response: JSON, updated "files" section of the pack and 200 status, 409 if the trying to use a shortcode
  that is already taken, 400 if there was an error with the shortcode, filename or file (additional info
  in the "error" part of the response JSON)

## `POST /api/pleroma/emoji/packs/:name/update_metadata`
### Updates (replaces) pack metadata
* Method `POST`
* Authentication: required
* Params:
  * `new_data`: new metadata to replace the old one
* Response: JSON, updated "metadata" section of the pack and 200 status or 400 if there was a
  problem with the new metadata (the error is specified in the "error" part of the response JSON)

## `POST /api/pleroma/emoji/packs/download_from`
### Requests the instance to download the pack from another instance
* Method `POST`
* Authentication: required
* Params:
  * `instance_address`: the address of the instance to download from
  * `pack_name`: the pack to download from that instance
* Response: JSON, "ok" and 200 status if the pack was downloaded, or 500 if there were
  errors downloading the pack

## `POST /api/pleroma/emoji/packs/list_from`
### Requests the instance to list the packs from another instance
* Method `POST`
* Authentication: required
* Params:
  * `instance_address`: the address of the instance to download from
* Response: JSON with the pack list, same as if the request was made to that instance's
  list endpoint directly + 200 status

## `GET /api/pleroma/emoji/packs/:name/download_shared`
### Requests a local pack from the instance
* Method `GET`
* Authentication: not required
* Params: None
* Response: the archive of the pack with a 200 status code, 403 if the pack is not set as shared,
  404 if the pack does not exist

## `GET /api/v1/pleroma/accounts/:id/scrobbles`
### Requests a list of current and recent Listen activities for an account
* Method `GET`
* Authentication: not required
* Params: None
* Response: An array of media metadata entities.
* Example response:
```json
[
   {
       "account": {...},
       "id": "1234",
       "title": "Some Title",
       "artist": "Some Artist",
       "album": "Some Album",
       "length": 180000,
       "created_at": "2019-09-28T12:40:45.000Z"
   }
]
```

## `POST /api/v1/pleroma/scrobble`
### Creates a new Listen activity for an account
* Method `POST`
* Authentication: required
* Params:
  * `title`: the title of the media playing
  * `album`: the album of the media playing [optional]
  * `artist`: the artist of the media playing [optional]
  * `length`: the length of the media playing [optional]
* Response: the newly created media metadata entity representing the Listen activity

# Emoji Reactions

Emoji reactions work a lot like favourites do. They make it possible to react to a post with a single emoji character.

## `POST /api/v1/pleroma/statuses/:id/react_with_emoji`
### React to a post with a unicode emoji
* Method: `POST`
* Authentication: required
* Params: `emoji`: A single character unicode emoji
* Response: JSON, the status.

## `POST /api/v1/pleroma/statuses/:id/unreact_with_emoji`
### Remove a reaction to a post with a unicode emoji
* Method: `POST`
* Authentication: required
* Params: `emoji`: A single character unicode emoji
* Response: JSON, the status.

## `GET /api/v1/pleroma/statuses/:id/emoji_reactions_by`
### Get an object of emoji to account mappings with accounts that reacted to the post
* Method: `GET`
* Authentication: optional
* Params: None
* Response: JSON, a map of emoji to account list mappings.
* Example Response:
```json
{
  "😀" => [{"id" => "xyz.."...}, {"id" => "zyx..."}],
  "🗡" => [{"id" => "abc..."}] 
}
```
