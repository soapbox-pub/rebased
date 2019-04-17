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
```
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

## `/api/v1/pleroma/flavour/:flavour`
* Method `POST`
* Authentication: required
* Response: JSON string. Returns the user flavour or the default one on success, otherwise returns `{"error": "error_msg"}`
* Example response: "glitch"
* Note: This is intended to be used only by mastofe

## `/api/v1/pleroma/flavour`
* Method `GET`
* Authentication: required
* Response: JSON string. Returns the user flavour or the default one.
* Example response: "glitch"
* Note: This is intended to be used only by mastofe

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
