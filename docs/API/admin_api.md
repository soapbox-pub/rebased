# Admin API

Authentication is required and the user must be an admin.

## `/api/pleroma/admin/users`

### List users

- Method `GET`
- Query Params:
  - *optional* `query`: **string** search term (e.g. nickname, domain, nickname@domain)
  - *optional* `filters`: **string** comma-separated string of filters:
    - `local`: only local users
    - `external`: only external users
    - `active`: only active users
    - `deactivated`: only deactivated users
    - `is_admin`: users with admin role
    - `is_moderator`: users with moderator role
  - *optional* `page`: **integer** page number
  - *optional* `page_size`: **integer** number of users per page (default is `50`)
  - *optional* `tags`: **[string]** tags list
  - *optional* `name`: **string** user display name
  - *optional* `email`: **string** user email
- Example: `https://mypleroma.org/api/pleroma/admin/users?query=john&filters=local,active&page=1&page_size=10&tags[]=some_tag&tags[]=another_tag&name=display_name&email=email@example.com`
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
      "display_name": string
    },
    ...
  ]
}
```

## DEPRECATED `DELETE /api/pleroma/admin/users`

### Remove a user

- Method `DELETE`
- Params:
  - `nickname`
- Response: User’s nickname

## `DELETE /api/pleroma/admin/users`

### Remove a user

- Method `DELETE`
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

## `/api/pleroma/admin/users/follow`
### Make a user follow another user

- Methods: `POST`
- Params:
 - `follower`: The nickname of the follower
 - `followed`: The nickname of the followed
- Response:
 - "ok"

## `/api/pleroma/admin/users/unfollow`
### Make a user unfollow another user

- Methods: `POST`
- Params:
 - `follower`: The nickname of the follower
 - `followed`: The nickname of the followed
- Response:
 - "ok"

## `/api/pleroma/admin/users/:nickname/toggle_activation`

### Toggle user activation

- Method: `PATCH`
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

## `/api/pleroma/admin/users/tag`

### Tag a list of users

- Method: `PUT`
- Params:
  - `nicknames` (array)
  - `tags` (array)

### Untag a list of users

- Method: `DELETE`
- Params:
  - `nicknames` (array)
  - `tags` (array)

## `/api/pleroma/admin/users/:nickname/permission_group`

### Get user user permission groups membership

- Method: `GET`
- Params: none
- Response:

```json
{
  "is_moderator": bool,
  "is_admin": bool
}
```

## `/api/pleroma/admin/users/:nickname/permission_group/:permission_group`

Note: Available `:permission_group` is currently moderator and admin. 404 is returned when the permission group doesn’t exist.

### Get user user permission groups membership per permission group

- Method: `GET`
- Params: none
- Response:

```json
{
  "is_moderator": bool,
  "is_admin": bool
}
```

## DEPRECATED `POST /api/pleroma/admin/users/:nickname/permission_group/:permission_group`

### Add user to permission group

- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user

## `POST /api/pleroma/admin/users/permission_group/:permission_group`

### Add users to permission group

- Params:
  - `nicknames`: nicknames array
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user

## DEPRECATED `DELETE /api/pleroma/admin/users/:nickname/permission_group/:permission_group`

### Remove user from permission group

- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user
- Note: An admin cannot revoke their own admin status.

## `DELETE /api/pleroma/admin/users/permission_group/:permission_group`

### Remove users from permission group

- Params:
  - `nicknames`: nicknames array
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the user
- Note: An admin cannot revoke their own admin status.

## `PATCH /api/pleroma/admin/users/activate`

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

## `PATCH /api/pleroma/admin/users/deactivate`

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

## DEPRECATED `PATCH /api/pleroma/admin/users/:nickname/activation_status`

### Active or deactivate a user

- Params:
  - `nickname`
  - `status` BOOLEAN field, false value means deactivation.

## `/api/pleroma/admin/users/:nickname_or_id`

### Retrive the details of a user

- Method: `GET`
- Params:
  - `nickname` or `id`
- Response:
  - On failure: `Not found`
  - On success: JSON of the user

## `/api/pleroma/admin/users/:nickname_or_id/statuses`

### Retrive user's latest statuses

- Method: `GET`
- Params:
  - `nickname` or `id`
  - *optional* `page_size`: number of statuses to return (default is `20`)
  - *optional* `godmode`: `true`/`false` – allows to see private statuses
- Response:
  - On failure: `Not found`
  - On success: JSON array of user's latest statuses

## `/api/pleroma/admin/relay`

### Follow a Relay

- Methods: `POST`
- Params:
  - `relay_url`
- Response:
  - On success: URL of the followed relay

### Unfollow a Relay

- Methods: `DELETE`
- Params:
  - `relay_url`
- Response:
  - On success: URL of the unfollowed relay

## `GET /api/pleroma/admin/relay`

### List Relays

- Params: none
- Response:
  - On success: JSON array of relays

## `/api/pleroma/admin/users/invite_token`

### Create an account registration invite token

- Methods: `POST`
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

## `/api/pleroma/admin/users/invites`

### Get a list of generated invites

- Methods: `GET`
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

## `/api/pleroma/admin/users/revoke_invite`

### Revoke invite by token

- Methods: `POST`
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


## `/api/pleroma/admin/users/email_invite`

### Sends registration invite via email

- Methods: `POST`
- Params:
  - `email`
  - `name`, optional

## `/api/pleroma/admin/users/:nickname/password_reset`

### Get a password reset token for a given nickname

- Methods: `GET`
- Params: none
- Response:

```json
{
  "token": "base64 reset token",
  "link": "https://pleroma.social/api/pleroma/password_reset/url-encoded-base64-token"
}
```

## `/api/pleroma/admin/users/force_password_reset`

### Force passord reset for a user with a given nickname

- Methods: `PATCH`
- Params:
  - `nicknames`
- Response: none (code `204`)

## `/api/pleroma/admin/reports`
### Get a list of reports
- Method `GET`
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

## `/api/pleroma/admin/reports/:id`
### Get an individual report
- Method `GET`
- Params:
  - `id`
- Response:
  - On failure:
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: JSON, Report object (see above)

## `/api/pleroma/admin/reports/:id`
### Change the state of the report
- Method `PUT`
- Params:
  - `id`
  - `state`: required, the new state. Valid values are `open`, `closed` and `resolved`
- Response:
  - On failure:
    - 400 Bad Request `"Unsupported state"`
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: JSON, Report object (see above)

## `/api/pleroma/admin/reports/:id/respond`
### Respond to a report
- Method `POST`
- Params:
  - `id`
  - `status`: required, the message
- Response:
  - On failure:
    - 400 Bad Request `"Invalid parameters"` when `status` is missing
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: JSON, created Mastodon Status entity

```json
{
  "account": { ... },
  "application": {
    "name": "Web",
    "website": null
  },
  "bookmarked": false,
  "card": null,
  "content": "Your claim is going to be closed",
  "created_at": "2019-05-11T17:13:03.000Z",
  "emojis": [],
  "favourited": false,
  "favourites_count": 0,
  "id": "9ihuiSL1405I65TmEq",
  "in_reply_to_account_id": null,
  "in_reply_to_id": null,
  "language": null,
  "media_attachments": [],
  "mentions": [
    {
      "acct": "user",
      "id": "9i6dAJqSGSKMzLG2Lo",
      "url": "https://pleroma.example.org/users/user",
      "username": "user"
    },
    {
      "acct": "admin",
      "id": "9hEkA5JsvAdlSrocam",
      "url": "https://pleroma.example.org/users/admin",
      "username": "admin"
    }
  ],
  "muted": false,
  "pinned": false,
  "pleroma": {
    "content": {
      "text/plain": "Your claim is going to be closed"
    },
    "conversation_id": 35,
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
  "uri": "https://pleroma.example.org/objects/cab0836d-9814-46cd-a0ea-529da9db5fcb",
  "url": "https://pleroma.example.org/notice/9ihuiSL1405I65TmEq",
  "visibility": "direct"
}
```

## `/api/pleroma/admin/statuses/:id`
### Change the scope of an individual reported status
- Method `PUT`
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

## `/api/pleroma/admin/statuses/:id`
### Delete an individual reported status
- Method `DELETE`
- Params:
  - `id`
- Response:
  - On failure:
    - 403 Forbidden `{"error": "error_msg"}`
    - 404 Not Found `"Not found"`
  - On success: 200 OK `{}`


## `/api/pleroma/admin/config/migrate_to_db`
### Run mix task pleroma.config migrate_to_db
Copy settings on key `:pleroma` to DB.
- Method `GET`
- Params: none
- Response:

```json
{}
```

## `/api/pleroma/admin/config/migrate_from_db`
### Run mix task pleroma.config migrate_from_db
Copy all settings from DB to `config/prod.exported_from_db.secret.exs` with deletion from DB.
- Method `GET`
- Params: none
- Response:

```json
{}
```

## `/api/pleroma/admin/config`
### List config settings
List config settings only works with `:pleroma => :instance => :dynamic_configuration` setting to `true`.
- Method `GET`
- Params: none
- Response:

```json
{
  configs: [
    {
      "group": string,
      "key": string or string with leading `:` for atoms,
      "value": string or {} or [] or {"tuple": []}
     }
  ]
}
```

## `/api/pleroma/admin/config`
### Update config settings
Updating config settings only works with `:pleroma => :instance => :dynamic_configuration` setting to `true`.
Module name can be passed as string, which starts with `Pleroma`, e.g. `"Pleroma.Upload"`.
Atom keys and values can be passed with `:` in the beginning, e.g. `":upload"`.
Tuples can be passed as `{"tuple": ["first_val", Pleroma.Module, []]}`.
`{"tuple": ["some_string", "Pleroma.Some.Module", []]}` will be converted to `{"some_string", Pleroma.Some.Module, []}`.
Keywords can be passed as lists with 2 child tuples, e.g.
`[{"tuple": ["first_val", Pleroma.Module]}, {"tuple": ["second_val", true]}]`.

If value contains list of settings `[subkey: val1, subkey2: val2, subkey3: val3]`, it's possible to remove only subkeys instead of all settings passing `subkeys` parameter. E.g.:
{"group": "pleroma", "key": "some_key", "delete": "true", "subkeys": [":subkey", ":subkey3"]}.

Compile time settings (need instance reboot):
- all settings by this keys:
  - `:hackney_pools`
  - `:chat`
  - `Pleroma.Web.Endpoint`
  - `Pleroma.Repo`
- part settings:
  - `Pleroma.Captcha` -> `:seconds_valid`
  - `Pleroma.Upload` -> `:proxy_remote`
  - `:instance` -> `:upload_limit`

- Method `POST`
- Params:
  - `configs` => [
    - `group` (string)
    - `key` (string or string with leading `:` for atoms)
    - `value` (string, [], {} or {"tuple": []})
    - `delete` = true (optional, if parameter must be deleted)
    - `subkeys` [(string with leading `:` for atoms)] (optional, works only if `delete=true` parameter is passed, otherwise will be ignored)
  ]

- Request (example):

```json
{
  configs: [
    {
      "group": "pleroma",
      "key": "Pleroma.Upload",
      "value": [
        {"tuple": [":uploader", "Pleroma.Uploaders.Local"]},
        {"tuple": [":filters", ["Pleroma.Upload.Filter.Dedupe"]]},
        {"tuple": [":link_name", true]},
        {"tuple": [":proxy_remote", false]},
        {"tuple": [":proxy_opts", [
          {"tuple": [":redirect_on_failure", false]},
          {"tuple": [":max_body_length", 1048576]},
          {"tuple": [":http": [
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

```json
{
  configs: [
    {
      "group": string,
      "key": string or string with leading `:` for atoms,
      "value": string or {} or [] or {"tuple": []}
     }
  ]
}
```

## `/api/pleroma/admin/moderation_log`
### Get moderation log
- Method `GET`
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

## `POST /api/pleroma/admin/reload_emoji`
### Reload the instance's custom emoji
* Method `POST`
* Authentication: required
* Params: None
* Response: JSON, "ok" and 200 status
