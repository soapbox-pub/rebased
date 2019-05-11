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

```JSON
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
      "tags": array
    },
    ...
  ]
}
```

## `/api/pleroma/admin/users`

### Remove a user

- Method `DELETE`
- Params:
  - `nickname`
- Response: User’s nickname

### Create a user

- Method: `POST`
- Params:
  - `nickname`
  - `email`
  - `password`
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

```JSON
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
  - `nickname`
  - `tags`

### Untag a list of users

- Method: `DELETE`
- Params:
  - `nickname`
  - `tags`

## `/api/pleroma/admin/users/:nickname/permission_group`

### Get user user permission groups membership

- Method: `GET`
- Params: none
- Response:

```JSON
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

```JSON
{
  "is_moderator": bool,
  "is_admin": bool
}
```

### Add user in permission group

- Method: `POST`
- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the `user.info`

### Remove user from permission group

- Method: `DELETE`
- Params: none
- Response:
  - On failure: `{"error": "…"}`
  - On success: JSON of the `user.info`
- Note: An admin cannot revoke their own admin status.

## `/api/pleroma/admin/users/:nickname/activation_status`

### Active or deactivate a user

- Method: `PUT`
- Params:
  - `nickname`
  - `status` BOOLEAN field, false value means deactivation.

## `/api/pleroma/admin/users/:nickname`

### Retrive the details of a user

- Method: `GET`
- Params:
  - `nickname`
- Response:
  - On failure: `Not found`
  - On success: JSON of the user

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

## `/api/pleroma/admin/users/invite_token`

### Get an account registration invite token

- Methods: `GET`
- Params:
  - *optional* `invite` => [
    - *optional* `max_use` (integer)
    - *optional* `expires_at` (date string e.g. "2019-04-07")
  ]
- Response: invite token (base64 string)

## `/api/pleroma/admin/users/invites`

### Get a list of generated invites

- Methods: `GET`
- Params: none
- Response:

```JSON
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

```JSON
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
- Response: password reset token (base64 string)
