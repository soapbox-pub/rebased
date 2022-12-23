# Admin API

Authentication is required and the user must be an admin.

The `/api/v1/pleroma/admin/*` path is backwards compatible with `/api/pleroma/admin/*` (`/api/pleroma/admin/*` will be deprecated in the future).

## `GET /api/v1/pleroma/admin/users`

### List users

- Query Params:
  - *optional* `query`: **string** search term (e.g. nickname, domain, nickname@domain)
  - *optional* `filters`: **string** comma-separated string of filters:
    - `local`: only local users
    - `external`: only external users
    - `active`: only active users
    - `need_approval`: only unapproved users
    - `unconfirmed`: only unconfirmed users
    - `deactivated`: only deactivated users
    - `is_admin`: users with admin role
    - `is_moderator`: users with moderator role
  - *optional* `page`: **integer** page number
  - *optional* `page_size`: **integer** number of users per page (default is `50`)
  - *optional* `tags`: **[string]** tags list
  - *optional* `actor_types`: **[string]** actor type list (`Person`, `Service`, `Application`)
  - *optional* `name`: **string** user display name
  - *optional* `email`: **string** user email
- Example: `https://mypleroma.org/api/v1/pleroma/admin/users?query=john&filters=local,active&page=1&page_size=10&tags[]=some_tag&tags[]=another_tag&name=display_name&email=email@example.com`
- Response:

```json
{
  "page_size": integer,
  "count": integer,
  "users": [
    {
      "deactivated": bool,
      "id": integer,
      "nickname": string,
      "roles": {
        "admin": bool,
        "moderator": bool
      },
      "local": bool,
      "tags": array,
      "avatar": string,
      "display_name": string,
      "confirmation_pending": bool,
      "approval_pending": bool,
      "registration_reason": string,
    },
    ...
  ]
}
```

## DEPRECATED `DELETE /api/v1/pleroma/admin/users`

### Remove a user

- Params:
  - `nickname`
- Response: User’s nickname

## `DELETE /api/v1/pleroma/admin/users`

### Remove a user

- Params:
  - `nicknames`
- Response: Array of user nicknames

### Create a user

- Method: `POST`
- Params:
  `users`: [
    {
      `nickname`,
      `email`,
      `password`
    }
  ]
- Response: User’s nickname

## `POST /api/v1/pleroma/admin/users/follow`

### Make a user follow another user

- Params:
  - `follower`: The nickname of the follower
  - `followed`: The nickname of the followed
- Response:
  - "ok"

## `POST /api/v1/pleroma/admin/users/unfollow`

### Make a user unfollow another user

- Params:
  - `follower`: The nickname of the follower
  - `followed`: The nickname of the followed
- Response:
  - "ok"

## `PATCH /api/v1/pleroma/admin/users/:nickname/toggle_activation`

### Toggle user activation

- Params:
  - `nickname`
- Response: User’s object

```json
{
  "deactivated": bool,
  "id": integer,
  "nickname": string
}
```

## `PUT /api/v1/pleroma/admin/users/tag`

### Tag a list of users

- Params:
  - `nicknames` (array)
  - `tags` (array)

## `DELETE /api/v1/pleroma/admin/users/tag`

### Untag a list of users

- Params:
  - `nicknames` (array)
  - `tags` (array)

## `GET /api/v1/pleroma/admin/users/:nickname/permission_group`

### Get user user permission groups membership

- Params: none
- Response:

```json
{
  "is_moderator": bool,
  "is_admin": bool
}
```

## `GET /api/v1/pleroma/admin/users/:nickname/permission_group/:permission_group`

Note: Available `:permission_group` is currently moderator and admin. 404 is returned when the permission group doesn’t exist.

### Get user user permission groups membership per permission group

- Params: none
- Response:

```json
{
  "is_moderator": bool,
  "is_admin": bool
}
```

## DEPRECATED `POST /api/v1/pleroma/admin/users/:nickname/permission_group/:permission_group`

### Add user to permission group

- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user

## `POST /api/v1/pleroma/admin/users/permission_group/:permission_group`

### Add users to permission group

- Params:
  - `nicknames`: nicknames array
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user

## DEPRECATED `DELETE /api/v1/pleroma/admin/users/:nickname/permission_group/:permission_group`

## `DELETE /api/v1/pleroma/admin/users/:nickname/permission_group/:permission_group`

### Remove user from permission group

- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user
- Note: An admin cannot revoke their own admin status.

## `DELETE /api/v1/pleroma/admin/users/permission_group/:permission_group`

### Remove users from permission group

- Params:
  - `nicknames`: nicknames array
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user
- Note: An admin cannot revoke their own admin status.

## `PATCH /api/v1/pleroma/admin/users/activate`

### Activate user

- Params:
  - `nicknames`: nicknames array
- Response:

```json
{
  users: [
    {
      // user object
    }
  ]
}
```

## `PATCH /api/v1/pleroma/admin/users/deactivate`

### Deactivate user

- Params:
  - `nicknames`: nicknames array
- Response:

```json
{
  users: [
    {
      // user object
    }
  ]
}
```

## `PATCH /api/v1/pleroma/admin/users/approve`

### Approve user

- Params:
  - `nicknames`: nicknames array
- Response:

```json
{
  users: [
    {
      // user object
    }
  ]
}
```

## `PATCH /api/v1/pleroma/admin/users/suggest`

### Suggest a user

Adds the user(s) to follower recommendations.

- Params:
  - `nicknames`: nicknames array
- Response:

```json
{
  users: [
    {
      // user object
    }
  ]
}
```

## `PATCH /api/v1/pleroma/admin/users/unsuggest`

### Unsuggest a user

Removes the user(s) from follower recommendations.

- Params:
  - `nicknames`: nicknames array
- Response:

```json
{
  users: [
    {
      // user object
    }
  ]
}
```

## `GET /api/v1/pleroma/admin/users/:nickname_or_id`

### Retrive the details of a user

- Params:
  - `nickname` or `id`
- Response:
  - On failure: `Not found`
  - On success: JSON of the user

## `GET /api/v1/pleroma/admin/users/:nickname_or_id/statuses`

### Retrive user's latest statuses

- Params:
  - `nickname` or `id`
  - *optional* `page_size`: number of statuses to return (default is `20`)
  - *optional* `godmode`: `true`/`false` – allows to see private statuses
  - *optional* `with_reblogs`: `true`/`false` – allows to see reblogs (default is false)
- Response:
  - On failure: `Not found`
 - On success: JSON, where:
    - `total`: total count of the statuses for the user
    - `activities`: list of the statuses for the user

```json
{
  "total" : 1,
  "activities": [
    // activities list
  ]
}
```

## `GET /api/v1/pleroma/admin/instances/:instance/statuses`

### Retrive instance's latest statuses

- Params:
  - `instance`: instance name
  - *optional* `page_size`: number of statuses to return (default is `20`)
  - *optional* `godmode`: `true`/`false` – allows to see private statuses
  - *optional* `with_reblogs`: `true`/`false` – allows to see reblogs (default is false)
- Response:
  - On failure: `Not found`
  - On success: JSON, where:
    - `total`: total count of the statuses for the instance
    - `activities`: list of the statuses for the instance

```json
{
  "total" : 1,
  "activities": [
    // activities list
  ]
}
```

## `DELETE /api/v1/pleroma/admin/instances/:instance`

### Delete all users and activities from a remote instance

Note: this will trigger a job to remove instance content in the background.
It may take some time.

- Params:
  - `instance`: remote instance host
- Response:
  - The `instance` name as a string

```json
"lain.com"
```

## `GET /api/v1/pleroma/admin/statuses`

### Retrives all latest statuses

- Params:
  - *optional* `page_size`: number of statuses to return (default is `20`)
  - *optional* `local_only`: excludes remote statuses
  - *optional* `godmode`: `true`/`false` – allows to see private statuses
  - *optional* `with_reblogs`: `true`/`false` – allows to see reblogs (default is false)
- Response:
  - On failure: `Not found`
  - On success: JSON array of user's latest statuses

## `GET /api/v1/pleroma/admin/relay`

### List Relays

Params: none
Response:

* On success: JSON array of relays

```json
[
  {"actor": "https://example.com/relay", "followed_back": true},
  {"actor": "https://example2.com/relay", "followed_back": false}
]
```

## `POST /api/v1/pleroma/admin/relay`

### Follow a Relay

Params:

* `relay_url`

Response:

* On success: relay json object

```json
{"actor": "https://example.com/relay", "followed_back": true}
```

## `DELETE /api/v1/pleroma/admin/relay`

### Unfollow a Relay

- Params:
  - `relay_url`
  - *optional* `force`: forcefully unfollow a relay even when the relay is not available. (default is `false`)

Response:

* On success: URL of the unfollowed relay

```json
{"https://example.com/relay"}
```

## `POST /api/v1/pleroma/admin/users/invite_token`

### Create an account registration invite token

- Params:
  - *optional* `max_use` (integer)
  - *optional* `expires_at` (date string e.g. "2019-04-07")
- Response:

```json
{
  "id": integer,
  "token": string,
  "used": boolean,
  "expires_at": date,
  "uses": integer,
  "max_use": integer,
  "invite_type": string (possible values: `one_time`, `reusable`, `date_limited`, `reusable_date_limited`)
}
```

## `GET /api/v1/pleroma/admin/users/invites`

### Get a list of generated invites

- Params: none
- Response:

```json
{

  "invites": [
    {
      "id": integer,
      "token": string,
      "used": boolean,
      "expires_at": date,
      "uses": integer,
      "max_use": integer,
      "invite_type": string (possible values: `one_time`, `reusable`, `date_limited`, `reusable_date_limited`)
    },
    ...
  ]
}
```

## `POST /api/v1/pleroma/admin/users/revoke_invite`

### Revoke invite by token

- Params:
  - `token`
- Response:

```json
{
  "id": integer,
  "token": string,
  "used": boolean,
  "expires_at": date,
  "uses": integer,
  "max_use": integer,
  "invite_type": string (possible values: `one_time`, `reusable`, `date_limited`, `reusable_date_limited`)

}
```

## `POST /api/v1/pleroma/admin/users/email_invite`

### Sends registration invite via email

- Params:
  - `email`
  - `name`, optional

- Response:
  - On success: `204`, empty response
  - On failure:
    - 400 Bad Request, JSON:

    ```json
      [
        {
          "error": "Appropriate error message here"
        }
      ]
    ```

## `GET /api/v1/pleroma/admin/users/:nickname/password_reset`

### Get a password reset token for a given nickname


- Params: none
- Response:

```json
{
  "token": "base64 reset token",
  "link": "https://pleroma.social/api/v1/pleroma/password_reset/url-encoded-base64-token"
}
```

## `PATCH /api/v1/pleroma/admin/users/force_password_reset`

### Force passord reset for a user with a given nickname

- Params:
  - `nicknames`
- Response: none (code `204`)

## PUT `/api/v1/pleroma/admin/users/disable_mfa`

### Disable mfa for user's account.

- Params:
  - `nickname`
- Response: User’s nickname

## `GET /api/v1/pleroma/admin/users/:nickname/credentials`

### Get the user's email, password, display and settings-related fields

- Params:
  - `nickname`

- Response:

```json
{
  "actor_type": "Person",
  "allow_following_move": true,
  "avatar": "https://pleroma.social/media/7e8e7508fd545ef580549b6881d80ec0ff2c81ed9ad37b9bdbbdf0e0d030159d.jpg",
  "background": "https://pleroma.social/media/4de34c0bd10970d02cbdef8972bef0ebbf55f43cadc449554d4396156162fe9a.jpg",
  "banner": "https://pleroma.social/media/8d92ba2bd244b613520abf557dd448adcd30f5587022813ee9dd068945986946.jpg",
  "bio": "bio",
  "default_scope": "public",
  "discoverable": false,
  "email": "user@example.com",
  "fields": [
    {
      "name": "example",
      "value": "<a href=\"https://example.com\" rel=\"ugc\">https://example.com</a>"
    }
  ],
  "hide_favorites": false,
  "hide_followers": false,
  "hide_followers_count": false,
  "hide_follows": false,
  "hide_follows_count": false,
  "id": "9oouHaEEUR54hls968",
  "locked": true,
  "name": "user",
  "no_rich_text": true,
  "pleroma_settings_store": {},
  "raw_fields": [
    {
      "id": 1,
      "name": "example",
      "value": "https://example.com"
    },
  ],
  "show_role": true,
  "skip_thread_containment": false
}
```

## `PATCH /api/v1/pleroma/admin/users/:nickname/credentials`

### Change the user's email, password, display and settings-related fields

* Params:
  * `email`
  * `password`
  * `name`
  * `bio`
  * `avatar`
  * `locked`
  * `no_rich_text`
  * `default_scope`
  * `banner`
  * `hide_follows`
  * `hide_followers`
  * `hide_followers_count`
  * `hide_follows_count`
  * `hide_favorites`
  * `allow_following_move`
  * `background`
  * `show_role`
  * `skip_thread_containment`
  * `fields`
  * `is_discoverable`
  * `actor_type`

* Responses:

Status: 200

```json
{"status": "success"}
```

Status: 400

```json
{"errors":
  {"actor_type": "is invalid"},
  {"email": "has invalid format"},
  ...
 }
```

Status: 404

```json
{"error": "Not found"}
```

## `GET /api/v1/pleroma/admin/reports`

### Get a list of reports

- Params:
  - *optional* `state`: **string** the state of reports. Valid values are `open`, `closed` and `resolved`
  - *optional* `limit`: **integer** the number of records to retrieve
  - *optional* `page`: **integer** page number
  - *optional* `page_size`: **integer** number of log entries per page (default is `50`)
- Response:
  - On failure: 403 Forbidden error `{"error": "error_msg"}` when requested by anonymous or non-admin
  - On success: JSON, returns a list of reports, where:
    - `account`: the user who has been reported
    - `actor`: the user who has sent the report
    - `statuses`: list of statuses that have been included to the report

```json
{
  "total" : 1,
  "reports": [
    {
      "account": {
        "acct": "user",
        "avatar": "https://pleroma.example.org/images/avi.png",
        "avatar_static": "https://pleroma.example.org/images/avi.png",
        "bot": false,
        "created_at": "2019-04-23T17:32:04.000Z",
        "display_name": "User",
        "emojis": [],
        "fields": [],
        "followers_count": 1,
        "following_count": 1,
        "header": "https://pleroma.example.org/images/banner.png",
        "header_static": "https://pleroma.example.org/images/banner.png",
        "id": "9i6dAJqSGSKMzLG2Lo",
        "locked": false,
        "note": "",
        "pleroma": {
          "confirmation_pending": false,
          "hide_favorites": true,
          "hide_followers": false,
          "hide_follows": false,
          "is_admin": false,
          "is_moderator": false,
          "relationship": {},
          "tags": []
        },
        "source": {
          "note": "",
          "pleroma": {},
          "sensitive": false
        },
        "tags": ["force_unlisted"],
        "statuses_count": 3,
        "url": "https://pleroma.example.org/users/user",
        "username": "user"
      },
      "actor": {
        "acct": "lain",
        "avatar": "https://pleroma.example.org/images/avi.png",
        "avatar_static": "https://pleroma.example.org/images/avi.png",
        "bot": false,
        "created_at": "2019-03-28T17:36:03.000Z",
        "display_name": "Roger Braun",
        "emojis": [],
        "fields": [],
        "followers_count": 1,
        "following_count": 1,
        "header": "https://pleroma.example.org/images/banner.png",
        "header_static": "https://pleroma.example.org/images/banner.png",
        "id": "9hEkA5JsvAdlSrocam",
        "locked": false,
        "note": "",
        "pleroma": {
          "confirmation_pending": false,
          "hide_favorites": false,
          "hide_followers": false,
          "hide_follows": false,
          "is_admin": false,
          "is_moderator": false,
          "relationship": {},
          "tags": []
        },
        "source": {
          "note": "",
          "pleroma": {},
          "sensitive": false
        },
        "tags": ["force_unlisted"],
        "statuses_count": 1,
        "url": "https://pleroma.example.org/users/lain",
        "username": "lain"
      },
      "content": "Please delete it",
      "created_at": "2019-04-29T19:48:15.000Z",
      "id": "9iJGOv1j8hxuw19bcm",
      "state": "open",
      "statuses": [
        {
          "account": { ... },
          "application": {
            "name": "Web",
            "website": null
          },
          "bookmarked": false,
          "card": null,
          "content": "<span class=\"h-card\"><a data-user=\"9hEkA5JsvAdlSrocam\" class=\"u-url mention\" href=\"https://pleroma.example.org/users/lain\">@<span>lain</span></a></span> click on my link <a href=\"https://www.google.com/\">https://www.google.com/</a>",
          "created_at": "2019-04-23T19:15:47.000Z",
          "emojis": [],
          "favourited": false,
          "favourites_count": 0,
          "id": "9i6mQ9uVrrOmOime8m",
          "in_reply_to_account_id": null,
          "in_reply_to_id": null,
          "language": null,
          "media_attachments": [],
          "mentions": [
            {
              "acct": "lain",
              "id": "9hEkA5JsvAdlSrocam",
              "url": "https://pleroma.example.org/users/lain",
              "username": "lain"
            },
            {
              "acct": "user",
              "id": "9i6dAJqSGSKMzLG2Lo",
              "url": "https://pleroma.example.org/users/user",
              "username": "user"
            }
          ],
          "muted": false,
          "pinned": false,
          "pleroma": {
            "content": {
              "text/plain": "@lain click on my link https://www.google.com/"
            },
            "conversation_id": 28,
            "in_reply_to_account_acct": null,
            "local": true,
            "spoiler_text": {
              "text/plain": ""
            }
          },
          "reblog": null,
          "reblogged": false,
          "reblogs_count": 0,
          "replies_count": 0,
          "sensitive": false,
          "spoiler_text": "",
          "tags": [],
          "uri": "https://pleroma.example.org/objects/8717b90f-8e09-4b58-97b0-e3305472b396",
          "url": "https://pleroma.example.org/notice/9i6mQ9uVrrOmOime8m",
          "visibility": "direct"
        }
      ]
    }
  ]
}
```

## `GET /api/v1/pleroma/admin/grouped_reports`

### Get a list of reports, grouped by status

- Params: none
- On success: JSON, returns a list of reports, where:
  - `date`: date of the latest report
  - `account`: the user who has been reported (see `/api/v1/pleroma/admin/reports` for reference)
  - `status`: reported status (see `/api/v1/pleroma/admin/reports` for reference)
  - `actors`: users who had reported this status (see `/api/v1/pleroma/admin/reports` for reference)
  - `reports`: reports (see `/api/v1/pleroma/admin/reports` for reference)

```json
  "reports": [
    {
      "date": "2019-10-07T12:31:39.615149Z",
      "account": { ... },
      "status": { ... },
      "actors": [{ ... }, { ... }],
      "reports": [{ ... }]
    }
  ]
```

## `GET /api/v1/pleroma/admin/reports/:id`

### Get an individual report

- Params:
  - `id`
- Response:
  - On failure:
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: JSON, Report object (see above)

## `PATCH /api/v1/pleroma/admin/reports`

### Change the state of one or multiple reports

- Params:

```json
  `reports`: [
    {
      `id`, // required, report id
      `state` // required, the new state. Valid values are `open`, `closed` and `resolved`
    },
    ...
  ]
```

- Response:
  - On failure:
    - 400 Bad Request, JSON:

    ```json
      [
        {
          `id`, // report id
          `error` // error message
        }
      ]
    ```

  - On success: `204`, empty response

## `POST /api/v1/pleroma/admin/reports/:id/notes`

### Create report note

- Params:
  - `id`: required, report id
  - `content`: required, the message
- Response:
  - On failure:
    - 400 Bad Request `"Invalid parameters"` when `status` is missing
  - On success: `204`, empty response

## `DELETE /api/v1/pleroma/admin/reports/:report_id/notes/:id`

### Delete report note

- Params:
  - `report_id`: required, report id
  - `id`: required, note id
- Response:
  - On failure:
    - 400 Bad Request `"Invalid parameters"` when `status` is missing
  - On success: `204`, empty response

## `GET /api/v1/pleroma/admin/statuses/:id`

### Show status by id

- Params:
  - `id`: required, status id
- Response:
  - On failure:
    - 404 Not Found `"Not Found"`
  - On success: JSON, Mastodon Status entity

## `PUT /api/v1/pleroma/admin/statuses/:id`

### Change the scope of an individual reported status

- Params:
  - `id`
  - `sensitive`: optional, valid values are `true` or `false`
  - `visibility`: optional, valid values are `public`, `private` and `unlisted`
- Response:
  - On failure:
    - 400 Bad Request `"Unsupported visibility"`
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: JSON, Mastodon Status entity

## `DELETE /api/v1/pleroma/admin/statuses/:id`

### Delete an individual reported status

- Params:
  - `id`
- Response:
  - On failure:
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: 200 OK `{}`

## `GET /api/v1/pleroma/admin/restart`

### Restarts pleroma application

**Only works when configuration from database is enabled.**

- Params: none
- Response:
  - On failure:
    - 400 Bad Request `"To use this endpoint you need to enable configuration from database."`

```json
{}
```

## `GET /api/v1/pleroma/admin/need_reboot`

### Returns the flag whether the pleroma should be restarted

- Params: none
- Response:
  - `need_reboot` - boolean
```json
{
  "need_reboot": false
}
```

## `GET /api/v1/pleroma/admin/config`

### Get list of merged default settings with saved in database.

*If `need_reboot` is `true`, instance must be restarted, so reboot time settings can take effect.*

**Only works when configuration from database is enabled.**

- Params:
  - `only_db`: true (*optional*, get only saved in database settings)
- Response:
  - On failure:
    - 400 Bad Request `"To use this endpoint you need to enable configuration from database."`

```json
{
  "configs": [
    {
      "group": ":pleroma",
      "key": "Pleroma.Upload",
      "value": []
     }
  ],
  "need_reboot": true
}
```

## `POST /api/v1/pleroma/admin/config`

### Update config settings

*If `need_reboot` is `true`, instance must be restarted, so reboot time settings can take effect.*

**Only works when configuration from database is enabled.**

Some modifications are necessary to save the config settings correctly:

- strings which start with `Pleroma.`, `Phoenix.`, `Tesla.` or strings like `Oban`, `Ueberauth` will be converted to modules;
```
"Pleroma.Upload" -> Pleroma.Upload
"Oban" -> Oban
```
- strings starting with `:` will be converted to atoms;
```
":pleroma" -> :pleroma
```
- objects with `tuple` key and array value will be converted to tuples;
```
{"tuple": ["string", "Pleroma.Upload", []]} -> {"string", Pleroma.Upload, []}
```
- arrays with *tuple objects* will be converted to keywords;
```
[{"tuple": [":key1", "value"]}, {"tuple": [":key2", "value"]}] -> [key1: "value", key2: "value"]
```

Most of the settings will be applied in `runtime`, this means that you don't need to restart the instance. But some settings are applied in `compile time` and require a reboot of the instance, such as:
- all settings inside these keys:
  - `:hackney_pools`
  - `:connections_pool`
  - `:pools`
  - `:chat`
- partially settings inside these keys:
  - `:seconds_valid` in `Pleroma.Captcha`
  - `:proxy_remote` in `Pleroma.Upload`
  - `:upload_limit` in `:instance`

- Params:
  - `configs` - array of config objects
  - config object params:
    - `group` - string (**required**)
    - `key` - string (**required**)
    - `value` - string, [], {} or {"tuple": []} (**required**)
    - `delete` - true (*optional*, if setting must be deleted)
    - `subkeys` - array of strings (*optional*, only works when `delete=true` parameter is passed, otherwise will be ignored)

*When a value have several nested settings, you can delete only some nested settings by passing a parameter `subkeys`, without deleting all settings by key.*
```
[subkey: val1, subkey2: val2, subkey3: val3] \\ initial value
{"group": ":pleroma", "key": "some_key", "delete": true, "subkeys": [":subkey", ":subkey3"]} \\ passing json for deletion
[subkey2: val2] \\ value after deletion
```

*Most of the settings can be partially updated through merge old values with new values, except settings value of which is list or is not keyword.*

Example of setting without keyword in value:
```elixir
config :tesla, :adapter, Tesla.Adapter.Hackney
```

List of settings which support only full update by key:
```elixir
@full_key_update [
    {:pleroma, :ecto_repos},
    {:mime, :types},
    {:cors_plug, [:max_age, :methods, :expose, :headers]},
    {:auto_linker, :opts},
    {:swarm, :node_blacklist},
    {:logger, :backends}
  ]
```

List of settings which support only full update by subkey:
```elixir
@full_subkey_update [
    {:pleroma, :assets, :mascots},
    {:pleroma, :emoji, :groups},
    {:pleroma, :workers, :retries},
    {:pleroma, :mrf_subchain, :match_actor},
    {:pleroma, :mrf_keyword, :replace}
  ]
```

*Settings without explicit key must be sent in separate config object params.*
```elixir
config :foo,
  bar: :baz,
  meta: [:data],
  ...
```
```json
{
  "configs": [
    {"group": ":foo", "key": ":bar", "value": ":baz"},
    {"group": ":foo", "key": ":meta", "value": [":data"]},
    ...
  ]
}
```
- Request:

```json
{
  "configs": [
    {
      "group": ":pleroma",
      "key": "Pleroma.Upload",
      "value": [
        {"tuple": [":uploader", "Pleroma.Uploaders.Local"]},
        {"tuple": [":filters", ["Pleroma.Upload.Filter.Dedupe"]]},
        {"tuple": [":link_name", true]},
        {"tuple": [":proxy_remote", false]},
        {"tuple": [":proxy_opts", [
          {"tuple": [":redirect_on_failure", false]},
          {"tuple": [":max_body_length", 1048576]},
          {"tuple": [":http", [
            {"tuple": [":follow_redirect", true]},
            {"tuple": [":pool", ":upload"]},
          ]]}
        ]
        ]},
        {"tuple": [":dispatch", {
          "tuple": ["/api/v1/streaming", "Pleroma.Web.MastodonAPI.WebsocketHandler", []]
        }]}
      ]
    }
  ]
}
```

- Response:
  - On failure:
    - 400 Bad Request `"To use this endpoint you need to enable configuration from database."`
```json
{
  "configs": [
    {
      "group": ":pleroma",
      "key": "Pleroma.Upload",
      "value": [...]
     }
  ],
  "need_reboot": true
}
```

## ` GET /api/v1/pleroma/admin/config/descriptions`

### Get JSON with config descriptions.
Loads json generated from `config/descriptions.exs`.

- Params: none
- Response:

```json
[{
    "group": ":pleroma", // string
    "key": "ModuleName", // string
    "type": "group", // string or list with possible values,
    "description": "Upload general settings", // string
    "children": [
      {
        "key": ":uploader", // string or module name `Pleroma.Upload`
        "type": "module",
        "description": "Module which will be used for uploads",
        "suggestions": ["module1", "module2"]
      },
      {
        "key": ":filters",
        "type": ["list", "module"],
        "description": "List of filter modules for uploads",
        "suggestions": [
          "module1", "module2", "module3"
        ]
      }
    ]
}]
```

## `GET /api/v1/pleroma/admin/moderation_log`

### Get moderation log

- Params:
  - *optional* `page`: **integer** page number
  - *optional* `page_size`: **integer** number of log entries per page (default is `50`)
  - *optional* `start_date`: **datetime (ISO 8601)** filter logs by creation date, start from `start_date`. Accepts datetime in ISO 8601 format (YYYY-MM-DDThh:mm:ss), e.g. `2005-08-09T18:31:42`
  - *optional* `end_date`: **datetime (ISO 8601)** filter logs by creation date, end by from `end_date`. Accepts datetime in ISO 8601 format (YYYY-MM-DDThh:mm:ss), e.g. 2005-08-09T18:31:42
  - *optional* `user_id`: **integer** filter logs by actor's id
  - *optional* `search`: **string** search logs by the log message
- Response:

```json
[
  {
    "id": 1234,
    "data": {
      "actor": {
        "id": 1,
        "nickname": "lain"
      },
      "action": "relay_follow"
    },
    "time": 1502812026, // timestamp
    "message": "[2017-08-15 15:47:06] @nick0 followed relay: https://example.org/relay" // log message
  }
]
```

## `POST /api/v1/pleroma/admin/reload_emoji`

### Reload the instance's custom emoji

- Authentication: required
- Params: None
- Response: JSON, "ok" and 200 status

## `PATCH /api/v1/pleroma/admin/users/confirm_email`

### Confirm users' emails

- Params:
  - `nicknames`
- Response: Array of user nicknames

## `PATCH /api/v1/pleroma/admin/users/resend_confirmation_email`

### Resend confirmation email

- Params:
  - `nicknames`
- Response: Array of user nicknames

## `GET /api/v1/pleroma/admin/stats`

### Stats

- Query Params:
  - *optional* `instance`: **string** instance hostname (without protocol) to get stats for
- Example: `https://mypleroma.org/api/v1/pleroma/admin/stats?instance=lain.com`

- Response:

```json
{
  "status_visibility": {
    "direct": 739,
    "private": 9,
    "public": 17,
    "unlisted": 14
  }
}
```

## `GET /api/v1/pleroma/admin/oauth_app`

### List OAuth app

- Params:
  - *optional* `name`
  - *optional* `client_id`
  - *optional* `page`
  - *optional* `page_size`
  - *optional* `trusted`

- Response:

```json
{
  "apps": [
    {
      "id": 1,
      "name": "App name",
      "client_id": "yHoDSiWYp5mPV6AfsaVOWjdOyt5PhWRiafi6MRd1lSk",
      "client_secret": "nLmis486Vqrv2o65eM9mLQx_m_4gH-Q6PcDpGIMl6FY",
      "redirect_uri": "https://example.com/oauth-callback",
      "website": "https://example.com",
      "trusted": true
    }
  ],
  "count": 17,
  "page_size": 50
}
```


## `POST /api/v1/pleroma/admin/oauth_app`

### Create OAuth App

- Params:
  - `name`
  - `redirect_uris`
  - `scopes`
  - *optional* `website`
  - *optional* `trusted`

- Response:

```json
{
  "id": 1,
  "name": "App name",
  "client_id": "yHoDSiWYp5mPV6AfsaVOWjdOyt5PhWRiafi6MRd1lSk",
  "client_secret": "nLmis486Vqrv2o65eM9mLQx_m_4gH-Q6PcDpGIMl6FY",
  "redirect_uri": "https://example.com/oauth-callback",
  "website": "https://example.com",
  "trusted": true
}
```

- On failure:
```json
{
  "redirect_uris": "can't be blank",
  "name": "can't be blank"
}
```

## `PATCH /api/v1/pleroma/admin/oauth_app/:id`

### Update OAuth App

- Params:
  -  *optional* `name`
  -  *optional* `redirect_uris`
  -  *optional* `scopes`
  -  *optional* `website`
  -  *optional* `trusted`

- Response:

```json
{
  "id": 1,
  "name": "App name",
  "client_id": "yHoDSiWYp5mPV6AfsaVOWjdOyt5PhWRiafi6MRd1lSk",
  "client_secret": "nLmis486Vqrv2o65eM9mLQx_m_4gH-Q6PcDpGIMl6FY",
  "redirect_uri": "https://example.com/oauth-callback",
  "website": "https://example.com",
  "trusted": true
}
```

## `DELETE /api/v1/pleroma/admin/oauth_app/:id`

### Delete OAuth App

- Params: None

- Response:
  - On success: `204`, empty response
  - On failure:
    - 400 Bad Request `"Invalid parameters"` when `status` is missing

## `GET /api/v1/pleroma/admin/media_proxy_caches`

### Get a list of all banned MediaProxy URLs in Cachex

- Authentication: required
- Params:
- *optional* `page`: **integer** page number
- *optional* `page_size`: **integer** number of log entries per page (default is `50`)
- *optional* `query`: **string** search term

- Response:

``` json
{
  "page_size": integer,
  "count": integer,
  "urls": [
    "http://example.com/media/a688346.jpg",
    "http://example.com/media/fb1f4d.jpg"
  ]
}

```

## `POST /api/v1/pleroma/admin/media_proxy_caches/delete`

### Remove a banned MediaProxy URL from Cachex

- Authentication: required
- Params:
  - `urls` (array)

- Response:

``` json
{ }

```

## `POST /api/v1/pleroma/admin/media_proxy_caches/purge`

### Purge a MediaProxy URL

- Authentication: required
- Params:
  - `urls` (array)
  - `ban` (boolean)

- Response:

``` json
{ }

```

## GET /api/v1/pleroma/admin/users/:nickname/chats

### List a user's chats

- Params: None

- Response:

```json
[
   {
      "sender": {
        "id": "someflakeid",
        "username": "somenick",
        ...
      },
      "receiver": {
        "id": "someflakeid",
        "username": "somenick",
        ...
      },
      "id" : "1",
      "unread" : 2,
      "last_message" : {...}, // The last message in that chat
      "updated_at": "2020-04-21T15:11:46.000Z"
   }
]
```

## GET /api/v1/pleroma/admin/chats/:chat_id

### View a single chat

- Params: None

- Response:

```json
{
  "sender": {
    "id": "someflakeid",
    "username": "somenick",
    ...
  },
  "receiver": {
    "id": "someflakeid",
    "username": "somenick",
    ...
  },
  "id" : "1",
  "unread" : 2,
  "last_message" : {...}, // The last message in that chat
  "updated_at": "2020-04-21T15:11:46.000Z"
}
```

## GET /api/v1/pleroma/admin/chats/:chat_id/messages

### List the messages in a chat

- Params: `max_id`, `min_id`

- Response:

```json
[
  {
    "account_id": "someflakeid",
    "chat_id": "1",
    "content": "Check this out :firefox:",
    "created_at": "2020-04-21T15:11:46.000Z",
    "emojis": [
      {
        "shortcode": "firefox",
        "static_url": "https://dontbulling.me/emoji/Firefox.gif",
        "url": "https://dontbulling.me/emoji/Firefox.gif",
        "visible_in_picker": false
      }
    ],
    "id": "13",
    "unread": true
  },
  {
    "account_id": "someflakeid",
    "chat_id": "1",
    "content": "Whats' up?",
    "created_at": "2020-04-21T15:06:45.000Z",
    "emojis": [],
    "id": "12",
    "unread": false
  }
]
```

## DELETE /api/v1/pleroma/admin/chats/:chat_id/messages/:message_id

### Delete a single message

- Params: None

- Response:

```json
{
  "account_id": "someflakeid",
  "chat_id": "1",
  "content": "Check this out :firefox:",
  "created_at": "2020-04-21T15:11:46.000Z",
  "emojis": [
    {
      "shortcode": "firefox",
      "static_url": "https://dontbulling.me/emoji/Firefox.gif",
      "url": "https://dontbulling.me/emoji/Firefox.gif",
      "visible_in_picker": false
    }
  ],
  "id": "13",
  "unread": false
}
```

## `GET /api/v1/pleroma/admin/instance_document/:document_name`

### Get an instance document

- Authentication: required

- Response:

Returns the content of the document

```html
<h1>Instance panel</h1>
```

## `PATCH /api/v1/pleroma/admin/instance_document/:document_name`
- Params:
  - `file` (the file to be uploaded, using multipart form data.)

### Update an instance document

- Authentication: required

- Response:

``` json
{
  "url": "https://example.com/instance/panel.html"
}
```

## `DELETE /api/v1/pleroma/admin/instance_document/:document_name`

### Delete an instance document

- Response:

``` json
{
  "url": "https://example.com/instance/panel.html"
}
```

## `GET /api/v1/pleroma/admin/frontends

### List available frontends

- Response:

```json
[
   {
    "build_url": "https://git.pleroma.social/pleroma/fedi-fe/-/jobs/artifacts/${ref}/download?job=build",
    "git": "https://git.pleroma.social/pleroma/fedi-fe",
    "installed": true,
    "name": "fedi-fe",
    "ref": "master"
  },
  {
    "build_url": "https://git.pleroma.social/lambadalambda/kenoma/-/jobs/artifacts/${ref}/download?job=build",
    "git": "https://git.pleroma.social/lambadalambda/kenoma",
    "installed": false,
    "name": "kenoma",
    "ref": "master"
  }
]
```

## `POST /api/v1/pleroma/admin/frontends/install`

### Install a frontend

- Params:
  - `name`: frontend name, required
  - `ref`: frontend ref
  - `file`: path to a frontend zip file
  - `build_url`: build URL
  - `build_dir`: build directory

- Response:

```json
[
   {
    "build_url": "https://git.pleroma.social/pleroma/fedi-fe/-/jobs/artifacts/${ref}/download?job=build",
    "git": "https://git.pleroma.social/pleroma/fedi-fe",
    "installed": true,
    "name": "fedi-fe",
    "ref": "master"
  },
  {
    "build_url": "https://git.pleroma.social/lambadalambda/kenoma/-/jobs/artifacts/${ref}/download?job=build",
    "git": "https://git.pleroma.social/lambadalambda/kenoma",
    "installed": false,
    "name": "kenoma",
    "ref": "master"
  }
]
```

```json
{
  "error": "Could not install frontend"
}
```

## `GET /api/v1/pleroma/admin/announcements`

### List announcements

- Params: `offset`, `limit`

- Response: JSON, list of announcements

```json
[
  {
    "id": "AHDp0GBdRn1EPN5HN2",
    "content": "some content",
    "starts_at": null,
    "ends_at": null,
    "all_day": false,
    "published_at": "2022-03-09T02:13:05",
    "reactions": [],
    "statuses": [],
    "tags": [],
    "emojis": [],
    "updated_at": "2022-03-09T02:13:05"
  }
]
```

Note that this differs from the Mastodon API variant: Mastodon API only returns *active* announcements, while this returns all.

## `GET /api/v1/pleroma/admin/announcements/:id`

### Display one announcement

- Response: JSON, one announcement

```json
{
  "id": "AHDp0GBdRn1EPN5HN2",
  "content": "some content",
  "starts_at": null,
  "ends_at": null,
  "all_day": false,
  "published_at": "2022-03-09T02:13:05",
  "reactions": [],
  "statuses": [],
  "tags": [],
  "emojis": [],
  "updated_at": "2022-03-09T02:13:05"
}
```

## `POST /api/v1/pleroma/admin/announcements`

### Create an announcement

- Params:
  - `content`: string, required, announcement content
  - `starts_at`: datetime, optional, default to null, the time when the announcement will become active (displayed to users); if it is null, the announcement will be active immediately
  - `ends_at`: datetime, optional, default to null, the time when the announcement will become inactive (no longer displayed to users); if it is null, the announcement will be active until an admin deletes it
  - `all_day`: boolean, optional, default to false, tells the client whether to only display dates for `starts_at` and `ends_at`

- Response: JSON, created announcement

```json
{
  "id": "AHDp0GBdRn1EPN5HN2",
  "content": "some content",
  "starts_at": null,
  "ends_at": null,
  "all_day": false,
  "published_at": "2022-03-09T02:13:05",
  "reactions": [],
  "statuses": [],
  "tags": [],
  "emojis": [],
  "updated_at": "2022-03-09T02:13:05"
}
```

## `PATCH /api/v1/pleroma/admin/announcements/:id`

### Change an announcement

- Params: same as `POST /api/v1/pleroma/admin/announcements`, except no param is required.

- Updates the announcement according to params. Missing params are kept as-is.

- Response: JSON, updated announcement

```json
{
  "id": "AHDp0GBdRn1EPN5HN2",
  "content": "some content",
  "starts_at": null,
  "ends_at": null,
  "all_day": false,
  "published_at": "2022-03-09T02:13:05",
  "reactions": [],
  "statuses": [],
  "tags": [],
  "emojis": [],
  "updated_at": "2022-03-09T02:13:05"
}
```

## `DELETE /api/v1/pleroma/admin/announcements/:id`

### Delete an announcement

- Response: JSON, empty object

```json
{}
```
