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

## `/api/account/register`
### Register a new user
* Method `POST`
* Authentication: not required
* Params:
    * `nickname`
    * `fullname`
    * `bio`
    * `email`
    * `password`
    * `confirm`
    * `captcha_solution`: optional, contains provider-specific captcha solution,
    * `captcha_token`: optional, contains provider-specific captcha token
    * `token`: invite token required when the registrations aren't public.
* Response: JSON. Returns a user object on success, otherwise returns `{"error": "error_msg"}`
* Example response:
```json
{
	"background_image": null,
	"cover_photo": "https://pleroma.soykaf.com/images/banner.png",
	"created_at": "Tue Dec 18 16:55:56 +0000 2018",
	"default_scope": "public",
	"description": "blushy-crushy fediverse idol + pleroma dev\nlet's be friends \nぷれろまの生徒会長。謎の外人。日本語OK. \n公主病.",
	"description_html": "blushy-crushy fediverse idol + pleroma dev.<br />let's be friends <br />ぷれろまの生徒会長。謎の外人。日本語OK. <br />公主病.",
	"favourites_count": 0,
	"fields": [],
	"followers_count": 0,
	"following": false,
	"follows_you": false,
	"friends_count": 0,
	"id": 6,
	"is_local": true,
	"locked": false,
	"name": "lain",
	"name_html": "lain",
	"no_rich_text": false,
	"pleroma": {
		"tags": []
	},
	"profile_image_url": "https://pleroma.soykaf.com/images/avi.png",
	"profile_image_url_https": "https://pleroma.soykaf.com/images/avi.png",
	"profile_image_url_original": "https://pleroma.soykaf.com/images/avi.png",
	"profile_image_url_profile_size": "https://pleroma.soykaf.com/images/avi.png",
	"rights": {
		"delete_others_notice": false
	},
	"screen_name": "lain",
	"statuses_count": 0,
	"statusnet_blocking": false,
	"statusnet_profile_url": "https://pleroma.soykaf.com/users/lain"
}
```

## `/api/pleroma/admin/`…
See [Admin-API](Admin-API.md)

## `/api/pleroma/notifications/read`
### Mark a single notification as read
* Method `POST`
* Authentication: required
* Params:
    * `id`: notification's id
* Response: JSON. Returns `{"status": "success"}` if the reading was successful, otherwise returns `{"error": "error_msg"}`

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
  "healthy": true # Instance state
}
```

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

# Emoji Reactions

Emoji reactions work a lot like favourites do. They make it possible to react to a post with a single emoji character.

## `POST /api/v1/pleroma/statuses/:id/react_with_emoji`
### React to a post with a unicode emoji
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
